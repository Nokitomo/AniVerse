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
    List<AnimeClass> popularItems = [];
    List<AnimeClass> latestItems = [];
    List<AnimeClass> topItems = [];

    try {
      final popularRaw = await popularAnime();
      popularItems = popularRaw.map(popularToObj).toList();
    } catch (e) {
      debugPrint("Carousel: errore popularAnime: $e");
    }

    try {
      final latestRaw = await latestAnime();
      latestItems = latestRaw.map(latestToObj).toList();
    } catch (e) {
      debugPrint("Carousel: errore latestAnime: $e");
    }

    try {
      final topRaw = await _fetchTopRated();
      topItems = topRaw.map(popularToObj).toList();
    } catch (e) {
      debugPrint("Carousel: errore fetchTopAnime: $e");
    }

    if (popularItems.isEmpty && latestItems.isEmpty && topItems.isEmpty) {
      throw Exception("Carousel: nessuna sorgente disponibile");
    }

    final selected = <AnimeClass>[];
    final usedIds = <int>{};

    void addFrom(List<AnimeClass> source, int limit) {
      var added = 0;
      for (final item in source) {
        if (added >= limit) {
          break;
        }
        if (item.id == 0 || usedIds.contains(item.id)) {
          continue;
        }
        usedIds.add(item.id);
        selected.add(item);
        added += 1;
      }
    }

    addFrom(popularItems, 8);
    addFrom(latestItems, 6);
    addFrom(topItems, 6);

    if (selected.length < 20) {
      final allSources = <AnimeClass>[
        ...popularItems,
        ...latestItems,
        ...topItems,
      ];
      for (final item in allSources) {
        if (selected.length >= 20) {
          break;
        }
        if (item.id == 0 || usedIds.contains(item.id)) {
          continue;
        }
        usedIds.add(item.id);
        selected.add(item);
      }
    }

    final dedupedSelected = _dedupeCarouselItems(selected);
    if (dedupedSelected.length < 20) {
      final allSources = <AnimeClass>[
        ...popularItems,
        ...latestItems,
        ...topItems,
      ];
      for (final item in allSources) {
        if (dedupedSelected.length >= 20) {
          break;
        }
        if (_isCarouselDuplicate(dedupedSelected, item)) {
          continue;
        }
        dedupedSelected.add(item);
      }
    }

    final seed = _weeklySeed();
    dedupedSelected.shuffle(Random(seed));
    final result = dedupedSelected.take(20).toList();
    await _applyCarouselBanners(result);
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
    final now = DateTime.now();
    final cachedWeekKey = internalAPI.getBannerCacheWeekKey();
    final weekKey = _weekKey(now);
    final cache = internalAPI.getBannerCache();
    if (cachedWeekKey.isEmpty || cachedWeekKey != weekKey) {
      cache.clear();
    }
    final updatedCache = Map<String, String>.from(cache);

    const batchSize = 4;
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

    await internalAPI.setBannerCache(
      cache: updatedCache,
      weekKey: weekKey,
    );
  }

  List<AnimeClass> _dedupeCarouselItems(List<AnimeClass> items) {
    final seenIds = <int>{};
    final seenTitles = <String, int>{};
    final result = <AnimeClass>[];

    for (final item in items) {
      final id = item.id;
      final titleKey = item.title.trim().toLowerCase();
      if (id > 0 && seenIds.contains(id)) {
        continue;
      }

      if (titleKey.isNotEmpty && seenTitles.containsKey(titleKey)) {
        final index = seenTitles[titleKey]!;
        final existing = result[index];
        if (existing.bannerUrl.isEmpty && item.bannerUrl.isNotEmpty) {
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
    final titleKey = candidate.title.trim().toLowerCase();
    if (titleKey.isEmpty) {
      return false;
    }
    for (final item in items) {
      if (item.title.trim().toLowerCase() == titleKey) {
        return true;
      }
    }
    return false;
  }

  Future<List> _fetchTopRated() async {
    try {
      return await fetchTopAnime(order: 'rating');
    } catch (_) {
      // Alcuni endpoint rifiutano order=rating, prova fallback.
    }
    try {
      return await fetchTopAnime(order: 'score');
    } catch (_) {
      // Ignora per fallback finale.
    }
    return await fetchTopAnime();
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

