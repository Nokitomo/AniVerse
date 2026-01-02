import 'package:aniverse/settings/routes.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';

import '../../helper/classes/anime_obj.dart';

class AnimeCard extends StatefulWidget {
  final AnimeClass anime;
  final bool showProgress;

  const AnimeCard({
    super.key,
    required this.anime,
    this.showProgress = false,
  });

  @override
  State<AnimeCard> createState() => AnimeCardState();
}

class AnimeCardState extends State<AnimeCard> {
  final heroTag = UniqueKey();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
  }

  String _buildSubtitle(AnimeClass anime) {
    final hasEpisode = anime.episodeLabel.isNotEmpty;
    final hasProgress = anime.progressLabel.isNotEmpty;
    if (hasEpisode && hasProgress) {
      return '${anime.episodeLabel} · ${anime.progressLabel}';
    }
    if (hasEpisode) {
      return anime.episodeLabel;
    }
    return anime.progressLabel;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: colorScheme.primary.withOpacity(0.08),
      mouseCursor: SystemMouseCursors.click,
      onHover: (value) {
        if (_hovered != value) {
          setState(() {
            _hovered = value;
          });
        }
      },
      onTap: () async {
        await Get.toNamed(
          RouteGenerator.loadAnime,
          arguments: [widget.anime, heroTag],
        );
      },
      child: SizedBox(
        width: 150,
        child: Card(
          elevation: _hovered ? 4 : 0,
          shadowColor: colorScheme.primary.withOpacity(0.2),
          color: colorScheme.background,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(0),
                        color: Theme.of(context).colorScheme.background,
                        width: double.infinity,
                        height: double.infinity,
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
                                size: 35,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.anime.episodeLabel.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.anime.episodeLabel,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 150,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.anime.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.6,
                        ),
                      ),
                      if (widget.showProgress &&
                          (widget.anime.episodeLabel.isNotEmpty ||
                              widget.anime.progressLabel.isNotEmpty))
                        Text(
                          _buildSubtitle(widget.anime),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

