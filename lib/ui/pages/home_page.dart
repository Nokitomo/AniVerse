import 'package:aniverse/services/internal_api.dart';
import 'package:aniverse/settings/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../../helper/models/anime_model.dart';
import '../widgets/anime_row.dart';
import 'explore_section_page.dart';
import 'home_section_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final InternalAPI internalAPI = Get.find<InternalAPI>();

  final GlobalKey<State<StatefulWidget>> continueKey = GlobalKey();

  final rows = [
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
        () => HomeSectionPage(
          args: HomeSectionArgs(
            title: "Ultimi episodi",
            loader: latestAnime,
            converter: latestToObj,
          ),
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

  refresh() async {
    Get.offAllNamed(RouteGenerator.mainPage);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: RefreshIndicator(
            onRefresh: () => refresh(),
            child: ListView.separated(
              itemBuilder: (context, index) => rows[index],
              separatorBuilder: (context, index) => const SizedBox(height: 5),
              itemCount: rows.length,
            ),
          ),
        ),
      ),
    );
  }
}

