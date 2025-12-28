import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';

import '../../helper/classes/anime_obj.dart';
import '../../settings/routes.dart';

class ArchiveListItem extends StatefulWidget {
  final AnimeClass anime;

  const ArchiveListItem({
    super.key,
    required this.anime,
  });

  @override
  State<ArchiveListItem> createState() => _ArchiveListItemState();
}

class _ArchiveListItemState extends State<ArchiveListItem> {
  final heroTag = UniqueKey();

  List<String> _genreNames() {
    final genres = widget.anime.genres;
    if (genres is! List) {
      return [];
    }
    return genres
        .whereType<Map>()
        .map((e) => (e['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .take(3)
        .toList();
  }

  String _studioYearLabel() {
    final parts = <String>[];
    if (widget.anime.studio.isNotEmpty) {
      parts.add(widget.anime.studio);
    }
    if (widget.anime.year != null) {
      parts.add(widget.anime.year.toString());
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final genreLabel = _genreNames().join(', ');
    final studioYear = _studioYearLabel();
    final type = widget.anime.type.isNotEmpty ? widget.anime.type : 'TV';
    final episodes = widget.anime.episodesCount != 0
        ? widget.anime.episodesCount.toString()
        : '??';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Get.toNamed(
          RouteGenerator.loadAnime,
          arguments: [widget.anime, heroTag],
        );
      },
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 110,
                  height: 160,
                  child: Hero(
                    key: UniqueKey(),
                    tag: heroTag,
                    child: CachedNetworkImage(
                      imageUrl: widget.anime.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      studioYear.isNotEmpty ? studioYear : '$type • $episodes episodi',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.anime.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (genreLabel.isNotEmpty)
                      Text(
                        genreLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
