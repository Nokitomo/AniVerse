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
  static DateTime? _carouselCacheDay;

  Future<List<AnimeClass>> _loadCarouselItems() async {
    final now = DateTime.now();
    if (_carouselCache != null &&
        _carouselCache!.isNotEmpty &&
        _carouselCacheDay != null &&
        _isSameDay(_carouselCacheDay!, now)) {
      return _carouselCache!;
    }

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

    await _applyCarouselBanners(selected);

    final seed = _dailySeed();
    selected.shuffle(Random(seed));
    final result = selected.take(20).toList();
    _carouselCache = result;
    _carouselCacheDay = now;
    return result;
  }

  int _dailySeed() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    return now.year * 1000 + dayOfYear;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _applyCarouselBanners(List<AnimeClass> items) async {
    final now = DateTime.now();
    final cachedDay = internalAPI.getBannerCacheDay();
    final cache = internalAPI.getBannerCache();
    if (cachedDay == null || !_isSameDay(cachedDay, now)) {
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
            }
            return;
          }
          final banner = await fetchAnimeBannerUrl(
            animeId: anime.id,
            slug: anime.slug,
          );
          if (banner != null && banner.isNotEmpty) {
            anime.bannerUrl = banner;
            updatedCache[key] = banner;
          } else {
            updatedCache[key] = '';
          }
        }),
      );
    }

    await internalAPI.setBannerCache(
      cache: updatedCache,
      day: now,
    );
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

