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

  Future<List<AnimeClass>> _loadCarouselItems() async {
    final popularRaw = await popularAnime();
    final latestRaw = await latestAnime();
    final topRaw = await fetchTopAnime(order: 'rating');

    final popularItems = popularRaw.map(popularToObj).toList();
    final latestItems = latestRaw.map(latestToObj).toList();
    final topItems = topRaw.map(popularToObj).toList();

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

    final seed = _dailySeed();
    selected.shuffle(Random(seed));
    return selected.take(20).toList();
  }

  int _dailySeed() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    return now.year * 1000 + dayOfYear;
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

