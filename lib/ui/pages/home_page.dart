import 'package:aniverse/services/internal_api.dart';
import 'package:aniverse/settings/routes.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../../helper/models/anime_model.dart';
import '../widgets/anime_row.dart';
import '../widgets/home_carousel.dart';
import 'explore_section_page.dart';
import 'home_section_page.dart';
import 'latest_section_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final InternalAPI internalAPI = Get.find<InternalAPI>();

  final GlobalKey<State<StatefulWidget>> continueKey = GlobalKey();

  static List<AnimeClass>? _carouselCache;
  static String _carouselCacheWeekKey = '';
  static final Set<int> _bannerRetryIds = {};
  static const int _maxCarouselItems = 20;
  static const int _minCarouselItems = 10;

  Future<List<AnimeClass>> _loadCarouselItems() async {
    final now = DateTime.now();
    final weekKey = _weekKey(now);
    if (_carouselCache != null &&
        _carouselCache!.isNotEmpty &&
        _carouselCacheWeekKey.isNotEmpty &&
        _carouselCacheWeekKey == weekKey) {
      return _carouselCache!;
    }
    final persisted = _loadCarouselCacheFromPrefs(weekKey);
    if (persisted.isNotEmpty) {
      _carouselCache = persisted;
      _carouselCacheWeekKey = weekKey;
      _refreshCarouselCache(weekKey);
      return persisted;
    }

    return await _buildCarouselList(weekKey);
  }

  List<AnimeClass> _loadCarouselCacheFromPrefs(String weekKey) {
    final cachedWeekKey = internalAPI.getHomeCarouselCacheWeekKey();
    if (cachedWeekKey.isEmpty || cachedWeekKey != weekKey) {
      return [];
    }
    final cachedItems = internalAPI.getHomeCarouselCache();
    if (cachedItems.isEmpty) {
      return [];
    }
    return cachedItems
        .map((item) => AnimeClass.fromCarouselJson(item))
        .toList();
  }

  Future<void> _refreshCarouselCache(String weekKey) async {
    final refreshed = await _buildCarouselList(weekKey);
    _carouselCache = refreshed;
    _carouselCacheWeekKey = weekKey;
  }

  Future<List<AnimeClass>> _buildCarouselList(String weekKey) async {
    final usedIds = <int>{};
    final popularState = _CarouselCategoryState(
      target: 8,
      page: 1,
      lastPage: null,
      loader: (page) async {
        final pageData = await _fetchTopAnimePage(
          page: page,
          popular: true,
        );
        return _CarouselPageResult(
          items: pageData.items.map(popularToObj).toList(),
          hasMore: pageData.hasMore,
        );
      },
    );
    final latestState = _CarouselCategoryState(
      target: 6,
      page: 1,
      lastPage: null,
      loader: (page) async {
        final items = await fetchLatestAnimePage(page: page);
        return _CarouselPageResult(
          items: items.map(latestToObj).toList(),
          hasMore: items.isNotEmpty,
        );
      },
    );
    final topState = _CarouselCategoryState(
      target: 6,
      page: 1,
      lastPage: null,
      loader: (page) async {
        final pageData = await _fetchTopRatedPage(page: page);
        return _CarouselPageResult(
          items: pageData.items.map(popularToObj).toList(),
          hasMore: pageData.hasMore,
        );
      },
    );

    final selected = <AnimeClass>[];
    await _collectCategoryWithBanners(
      state: popularState,
      usedIds: usedIds,
      output: selected,
      maxPages: 2,
    );
    await _collectCategoryWithBanners(
      state: latestState,
      usedIds: usedIds,
      output: selected,
      maxPages: 2,
    );
    await _collectCategoryWithBanners(
      state: topState,
      usedIds: usedIds,
      output: selected,
      maxPages: 2,
    );

    if (selected.length < _minCarouselItems) {
      await _collectCategoryWithBanners(
        state: popularState,
        usedIds: usedIds,
        output: selected,
        maxPages: 6,
      );
      await _collectCategoryWithBanners(
        state: latestState,
        usedIds: usedIds,
        output: selected,
        maxPages: 6,
      );
      await _collectCategoryWithBanners(
        state: topState,
        usedIds: usedIds,
        output: selected,
        maxPages: 6,
      );
    }

    final dedupedSelected = _dedupeCarouselItems(selected);
    if (dedupedSelected.isEmpty) {
      throw Exception("Carousel: nessuna sorgente disponibile");
    }
    final seed = _weeklySeed();
    dedupedSelected.shuffle(Random(seed));
    final result = dedupedSelected.take(_maxCarouselItems).toList();
    await internalAPI.setHomeCarouselCache(
      items: result.map((item) => item.toCarouselJson()).toList(),
      weekKey: weekKey,
    );
    _carouselCache = result;
    _carouselCacheWeekKey = weekKey;
    return result;
  }

  int _weeklySeed() {
    final now = DateTime.now();
    final weekKey = _weekKey(now);
    return weekKey.hashCode;
  }

  String _weekKey(DateTime date) {
    final jan4 = DateTime(date.year, 1, 4);
    final jan4Weekday = jan4.weekday == 7 ? 0 : jan4.weekday;
    final weekStart = jan4.subtract(Duration(days: jan4Weekday - 1));
    final diffDays = date.difference(weekStart).inDays;
    final weekNumber = (diffDays / 7).floor() + 1;
    return "${date.year}-W$weekNumber";
  }

  Future<void> _applyCarouselBanners(List<AnimeClass> items) async {
    final cache = internalAPI.getBannerCache();
    final updatedCache = Map<String, String>.from(cache);

    const batchSize = 8;
    for (var i = 0; i < items.length; i += batchSize) {
      final batch = items.skip(i).take(batchSize);
      await Future.wait(
        batch.map((anime) async {
          if (anime.bannerUrl.isNotEmpty || anime.slug.isEmpty) {
            return;
          }
          final key = anime.id.toString();
          if (updatedCache.containsKey(key)) {
            final cachedValue = updatedCache[key] ?? '';
            if (cachedValue.isNotEmpty) {
              anime.bannerUrl = cachedValue;
              return;
            }
            if (_bannerRetryIds.contains(anime.id)) {
              return;
            }
          }
          final banner = await fetchAnimeBannerUrl(
            animeId: anime.id,
            slug: anime.slug,
          );
          _bannerRetryIds.add(anime.id);
          if (banner != null && banner.isNotEmpty) {
            anime.bannerUrl = banner;
            updatedCache[key] = banner;
          } else if (banner == '') {
            updatedCache[key] = '';
          }
        }),
      );
    }

    await internalAPI.setBannerCache(cache: updatedCache);
  }

  List<AnimeClass> _dedupeCarouselItems(List<AnimeClass> items) {
    final seenIds = <int>{};
    final seenTitles = <String, int>{};
    final result = <AnimeClass>[];

    for (final item in items) {
      final id = item.id;
      final titleKey = _normalizeCarouselTitle(item.title);
      final isDubbed = _isDubbedTitle(item.title);
      if (id > 0 && seenIds.contains(id)) {
        continue;
      }

      if (titleKey.isNotEmpty && seenTitles.containsKey(titleKey)) {
        final index = seenTitles[titleKey]!;
        final existing = result[index];
        final existingDubbed = _isDubbedTitle(existing.title);
        final shouldReplace = (!existingDubbed && isDubbed) ||
            (existing.bannerUrl.isEmpty && item.bannerUrl.isNotEmpty);
        if (shouldReplace) {
          result[index] = item;
        }
        if (id > 0) {
          seenIds.add(id);
        }
        continue;
      }

      if (id > 0) {
        seenIds.add(id);
      }
      if (titleKey.isNotEmpty) {
        seenTitles[titleKey] = result.length;
      }
      result.add(item);
    }

    return result;
  }

  bool _isCarouselDuplicate(List<AnimeClass> items, AnimeClass candidate) {
    if (candidate.id > 0) {
      for (final item in items) {
        if (item.id == candidate.id) {
          return true;
        }
      }
    }
    final titleKey = _normalizeCarouselTitle(candidate.title);
    if (titleKey.isEmpty) {
      return false;
    }
    for (final item in items) {
      if (_normalizeCarouselTitle(item.title) == titleKey) {
        final existingDubbed = _isDubbedTitle(item.title);
        final candidateDubbed = _isDubbedTitle(candidate.title);
        if (!existingDubbed && candidateDubbed) {
          return false;
        }
        return true;
      }
    }
    return false;
  }

  String _normalizeCarouselTitle(String title) {
    var normalized = title.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'\s*\(ita\)\s*$'), '');
    return normalized.trim();
  }

  bool _isDubbedTitle(String title) {
    return title.toLowerCase().contains('(ita)');
  }

  Future<_TopAnimePage> _fetchTopRatedPage({required int page}) async {
    try {
      return await _fetchTopAnimePage(
        page: page,
        order: 'rating',
      );
    } catch (_) {}
    try {
      return await _fetchTopAnimePage(
        page: page,
        order: 'score',
      );
    } catch (_) {}
    return await _fetchTopAnimePage(page: page);
  }

  Future<_TopAnimePage> _fetchTopAnimePage({
    required int page,
    bool popular = false,
    String? order,
  }) async {
    final pageData = await fetchTopAnimePage(
      page: page,
      popular: popular,
      order: order,
    );
    final items = pageData['data'] ?? [];
    final currentPage = pageData['current_page'] ?? page;
    final lastPage = pageData['last_page'] ?? page;
    final hasMore = currentPage < lastPage;
    return _TopAnimePage(
      items: items,
      hasMore: hasMore,
    );
  }

  Future<void> _collectCategoryWithBanners({
    required _CarouselCategoryState state,
    required Set<int> usedIds,
    required List<AnimeClass> output,
    required int maxPages,
  }) async {
    while (state.page <= maxPages &&
        output.length < _maxCarouselItems &&
        state.collected < state.target) {
      _CarouselPageResult result;
      try {
        result = await state.loader(state.page);
      } catch (e) {
        debugPrint("Carousel: errore fetch categoria: $e");
        break;
      }
      state.page += 1;
      if (result.items.isEmpty) {
        break;
      }

      final unique = <AnimeClass>[];
      for (final item in result.items) {
        if (item.id == 0 || usedIds.contains(item.id)) {
          continue;
        }
        if (_isCarouselDuplicate(output, item)) {
          continue;
        }
        unique.add(item);
      }

      if (unique.isEmpty) {
        if (!result.hasMore) {
          break;
        }
        continue;
      }

      final remaining = state.target - state.collected;
      final capacity = _maxCarouselItems - output.length;
      final needed = remaining < capacity ? remaining : capacity;
      final candidatesCount =
          unique.length < needed + 2 ? unique.length : needed + 2;
      final candidates = unique.take(candidatesCount).toList();

      await _applyCarouselBanners(candidates);
      for (final item in candidates) {
        if (item.bannerUrl.isEmpty) {
          continue;
        }
        if (item.id > 0) {
          usedIds.add(item.id);
        }
        output.add(item);
        state.collected += 1;
        if (state.collected >= state.target ||
            output.length >= _maxCarouselItems) {
          break;
        }
      }

      if (!result.hasMore) {
        break;
      }
    }
  }

  refresh() async {
    Get.offAllNamed(RouteGenerator.mainPage);
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      HomeHeroCarousel(
        loader: _loadCarouselItems,
      ),
      AnimeRow(
        key: UniqueKey(),
        function: toContinueAnime,
        name: "Riprendi a guardare",
        type: 3,
        actionLabel: "Vedi tutti",
        onAction: () => Get.to(
          () => HomeSectionPage(
            args: HomeSectionArgs(
              title: "Riprendi a guardare",
              loader: toContinueAnime,
              converter: (value) => modelToObj(value as AnimeModel),
            ),
          ),
        ),
      ),
      AnimeRow(
        function: latestAnime,
        name: "Ultimi episodi",
        type: 0,
        actionLabel: "Vedi tutti",
        onAction: () => Get.to(
          () => LatestSectionPage(
            title: "Ultimi episodi",
          ),
        ),
      ),
      AnimeRow(
        function: popularAnime,
        name: "Anime popolari",
        type: 1,
        actionLabel: "Vedi tutti",
        onAction: () => Get.to(
          () => ExploreSectionPage(
            args: ExploreSectionArgs(
              title: "Anime popolari",
              kind: ExploreSectionKind.topAnime,
              converter: popularToObj,
              popular: true,
            ),
          ),
        ),
      ),
      AnimeRow(
        function: searchAnime,
        name: "Tutti gli anime",
        type: 2,
        actionLabel: "Vedi tutti",
        onAction: () => Get.toNamed(RouteGenerator.archivePage),
      ),
    ];
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: RefreshIndicator(
            onRefresh: () => refresh(),
            child: ListView.separated(
              itemBuilder: (context, index) => rows[index],
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: rows.length,
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselCategoryState {
  _CarouselCategoryState({
    required this.target,
    required this.page,
    required this.lastPage,
    required this.loader,
  });

  final int target;
  int page;
  int? lastPage;
  int collected = 0;
  final Future<_CarouselPageResult> Function(int page) loader;
}

class _CarouselPageResult {
  _CarouselPageResult({
    required this.items,
    required this.hasMore,
  });

  final List<AnimeClass> items;
  final bool hasMore;
}

class _TopAnimePage {
  _TopAnimePage({
    required this.items,
    required this.hasMore,
  });

  final List items;
  final bool hasMore;
}

