import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../widgets/anime_row.dart';
import 'explore_section_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  static const int _previewLimit = 30;

  Future<List> _fetchArchivioType(String type) async {
    final response = await fetchArchivioAnimes(
      type: type,
      order: 'Valutazione',
      offset: 0,
    );
    return response['records'] ?? [];
  }

  void _openSection(ExploreSectionArgs args) {
    Get.to(() => ExploreSectionPage(args: args));
  }

  List<Widget> _buildRows() {
    return [
      AnimeRow(
        function: () => fetchTopAnime(status: 'In uscita prossimamente'),
        name: 'In uscita prossimamente',
        type: 1,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'In uscita prossimamente',
            kind: ExploreSectionKind.topAnime,
            converter: popularToObj,
            status: 'In uscita prossimamente',
          ),
        ),
      ),
      AnimeRow(
        function: () => fetchTopAnime(status: 'In Corso'),
        name: 'In corso',
        type: 1,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'In corso',
            kind: ExploreSectionKind.topAnime,
            converter: popularToObj,
            status: 'In Corso',
          ),
        ),
      ),
      AnimeRow(
        function: () => fetchTopAnime(popular: true),
        name: 'Popolari',
        type: 1,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'Popolari',
            kind: ExploreSectionKind.topAnime,
            converter: popularToObj,
            popular: true,
          ),
        ),
      ),
      AnimeRow(
        function: () => fetchTopAnime(order: 'most_viewed'),
        name: 'Più visti',
        type: 1,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'Più visti',
            kind: ExploreSectionKind.topAnime,
            converter: popularToObj,
            order: 'most_viewed',
          ),
        ),
      ),
      AnimeRow(
        function: () => fetchTopAnime(order: 'favorites'),
        name: 'Preferiti',
        type: 1,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'Preferiti',
            kind: ExploreSectionKind.topAnime,
            converter: popularToObj,
            order: 'favorites',
          ),
        ),
      ),
      AnimeRow(
        function: () => _fetchArchivioType('TV'),
        name: 'TV',
        type: 2,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'TV',
            kind: ExploreSectionKind.archivio,
            converter: searchToObj,
            type: 'TV',
            order: 'Valutazione',
          ),
        ),
      ),
      AnimeRow(
        function: () => _fetchArchivioType('Movie'),
        name: 'Movie',
        type: 2,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'Movie',
            kind: ExploreSectionKind.archivio,
            converter: searchToObj,
            type: 'Movie',
            order: 'Valutazione',
          ),
        ),
      ),
      AnimeRow(
        function: () => _fetchArchivioType('Special'),
        name: 'Special',
        type: 2,
        itemLimit: _previewLimit,
        actionLabel: 'Vedi tutti',
        onAction: () => _openSection(
          const ExploreSectionArgs(
            title: 'Special',
            kind: ExploreSectionKind.archivio,
            converter: searchToObj,
            type: 'Special',
            order: 'Valutazione',
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
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
