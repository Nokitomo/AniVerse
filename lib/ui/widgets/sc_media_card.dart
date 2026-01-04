import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/helper/classes/streamingcommunity_utils.dart';

class ScMediaCard extends StatefulWidget {
  final ScMedia media;
  final String cdnUrl;
  final VoidCallback? onTap;

  const ScMediaCard({
    super.key,
    required this.media,
    required this.cdnUrl,
    this.onTap,
  });

  @override
  State<ScMediaCard> createState() => _ScMediaCardState();
}

class _ScMediaCardState extends State<ScMediaCard> {
  bool _hovered = false;

  String _buildImageUrl() {
    return buildScImageUrl(
      images: widget.media.images,
      cdnUrl: widget.cdnUrl,
    );
  }

  String _typeLabel() {
    if (widget.media.isTv) {
      return 'Serie';
    }
    if (widget.media.isMovie) {
      return 'Film';
    }
    return widget.media.type.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _buildImageUrl();
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
      onTap: widget.onTap,
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
                        color: colorScheme.background,
                        width: double.infinity,
                        height: double.infinity,
                        child: imageUrl.isEmpty
                            ? const Center(
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 35,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 35,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _typeLabel(),
                            style: TextStyle(
                              color: colorScheme.onPrimary,
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
                  color: colorScheme.background,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.media.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.6,
                    ),
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
