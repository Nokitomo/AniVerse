import 'dart:ui';

import 'package:aniverse/helper/api.dart';
import 'package:aniverse/helper/models/anime_model.dart';
import 'package:aniverse/ui/widgets/details_content_fragments/episode_tile.dart';
import 'package:aniverse/ui/widgets/player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable_widgets/expandable_widgets.dart';
import 'package:flutter/material.dart';

import 'package:aniverse/helper/classes/anime_obj.dart';
import 'package:aniverse/services/internal_db.dart';
import 'package:get/get.dart';

class _EpisodeRange {
  final int start;
  final int end;

  const _EpisodeRange(this.start, this.end);

  String get label => '$start-$end';
}

class DetailsContent extends StatefulWidget {
  final AnimeClass anime;
  final Key heroTag;
  const DetailsContent({super.key, required this.anime, required this.heroTag});

  @override
  State<DetailsContent> createState() => _DetailsContentState();
}

class _DetailsContentState extends State<DetailsContent> {
  final ScrollController _controller = ScrollController();

  late final AnimeClass anime;
  late AnimeModel animeModel;

  late LoadingThings controller;
  late ResumeController resumeController;
  bool episodesLoading = true;
  bool episodesError = false;

  static const int _rangeSize = 120;
  int _rangeStart = 1;
  int _rangeEnd = _rangeSize;
  int _totalEpisodes = 0;
  int? _pendingResumeIndex;

  int getLatestIndex() {
    final lastIndex = animeModel.lastSeenEpisodeIndex ?? 0;
    final total = _totalEpisodes > 0 ? _totalEpisodes : anime.episodesCount;
    if (total > 0) {
      return lastIndex.clamp(0, total - 1);
    }
    return lastIndex < 0 ? 0 : lastIndex;
  }

  String _formatSeconds(int seconds) {
    if (seconds < 0) {
      return '0:00';
    }
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$minutes:$ss';
  }

  String _resumeLabel() {
    final index = getLatestIndex();
    final episodeNumber = index + 1;
    int? seconds;
    final lastId = animeModel.episodes['_lastEpisodeId'];
    if (lastId != null && animeModel.episodes.containsKey(lastId.toString())) {
      final entry = animeModel.episodes[lastId.toString()];
      if (entry is List && entry.isNotEmpty && entry[0] is int) {
        seconds = entry[0] as int;
      }
    }
    if (seconds == null && anime.episodes.isNotEmpty) {
      final localIndex = index - (_rangeStart - 1);
      if (localIndex >= 0 && localIndex < anime.episodes.length) {
        final episodeId = anime.episodes[localIndex]['id'];
        final entry = animeModel.episodes[episodeId.toString()];
        if (entry is List && entry.isNotEmpty && entry[0] is int) {
          seconds = entry[0] as int;
        }
      }
    }
    final time = seconds != null ? _formatSeconds(seconds) : null;
    if (time == null) {
      return 'Riprendi Ep. $episodeNumber';
    }
    return 'Riprendi Ep. $episodeNumber - $time';
  }

  List<_EpisodeRange> _buildRanges() {
    final total = _totalEpisodes > 0 ? _totalEpisodes : anime.episodesCount;
    if (total <= 0) {
      return const [];
    }
    final ranges = <_EpisodeRange>[];
    for (var start = 1; start <= total; start += _rangeSize) {
      final end = (start + _rangeSize - 1) <= total ? (start + _rangeSize - 1) : total;
      ranges.add(_EpisodeRange(start, end));
    }
    return ranges;
  }

  bool _isGlobalIndexInRange(int globalIndex) {
    final episodeNumber = globalIndex + 1;
    return episodeNumber >= _rangeStart && episodeNumber <= _rangeEnd;
  }

  int _globalToLocalIndex(int globalIndex) {
    return globalIndex - (_rangeStart - 1);
  }

  Future<void> _selectRange(_EpisodeRange range) async {
    setState(() {
      episodesLoading = true;
      episodesError = false;
      _rangeStart = range.start;
      _rangeEnd = range.end;
    });

    try {
      final response = await fetchAnimeEpisodesRange(
        animeId: anime.id,
        startRange: range.start,
        endRange: range.end,
        totalCountHint: _totalEpisodes > 0 ? _totalEpisodes : anime.episodesCount,
      );
      final episodes = response['episodes'] as List? ?? [];
      final totalCount = response['totalCount'] as int? ?? 0;

      setState(() {
        anime.episodes = episodes;
        episodesLoading = false;
        episodesError = false;
        if (totalCount > 0) {
          _totalEpisodes = totalCount;
          anime.episodesCount = totalCount;
        }
      });
      resumeController.index.value = getLatestIndex();
      controller.updateProgress();

      if (_pendingResumeIndex != null && _isGlobalIndexInRange(_pendingResumeIndex!)) {
        final pending = _pendingResumeIndex!;
        _pendingResumeIndex = null;
        await _playEpisodeAtGlobalIndex(pending);
      }
    } catch (e) {
      setState(() {
        episodesLoading = false;
        episodesError = true;
      });
    }
  }

  Future<void> _selectRangeForIndex(int globalIndex, {bool autoPlay = false}) async {
    final start = (globalIndex ~/ _rangeSize) * _rangeSize + 1;
    final end = start + _rangeSize - 1;
    if (autoPlay) {
      _pendingResumeIndex = globalIndex;
    }
    await _selectRange(_EpisodeRange(start, end));
  }

  void _trackProgressGlobal(int globalIndex) {
    animeModel.lastSeenDate = DateTime.now();
    animeModel.lastSeenEpisodeIndex = globalIndex;
    Get.find<ObjectBox>().store.box<AnimeModel>().put(animeModel);
    resumeController.updateIndex();
  }

  Future<void> _playEpisodeAtGlobalIndex(int globalIndex) async {
    if (!_isGlobalIndexInRange(globalIndex)) {
      return;
    }
    final localIndex = _globalToLocalIndex(globalIndex);
    if (localIndex < 0 || localIndex >= anime.episodes.length) {
      return;
    }

    controller.setLoading(true);
    controller.setError(false);
    _trackProgressGlobal(globalIndex);

    try {
      final episodeId = anime.episodes[localIndex]['id'];
      final link = await fetchEpisodeStreamUrl(episodeId);
      await Get.to(
        () => PlayerPage(
          url: link,
          colorScheme: Theme.of(Get.context!).colorScheme,
          animeId: anime.id,
          episodeId: episodeId,
          anime: anime,
        ),
      );
      controller.updateProgress();
      resumeController.updateIndex();
    } catch (e) {
      controller.setError(true);
    } finally {
      controller.setLoading(false);
    }
  }

  @override
  void initState() {
    anime = widget.anime;
    animeModel = fetchAnimeModel(anime);
    controller = LoadingThings(
      anime: anime,
      animeModel: animeModel,
      index: animeModel.lastSeenEpisodeIndex ?? 0,
    );

    resumeController = ResumeController(
      anime: anime,
      index_: getLatestIndex(),
    );

    _loadAnimeData();

    super.initState();
  }

  Future<void> _loadAnimeData() async {
    try {
      final results = await searchAnime(title: anime.title);
      if (results.isNotEmpty) {
        final match = results.cast<Map>().firstWhere(
              (item) => item["id"] == anime.id,
              orElse: () => results.first,
            );
        anime.title = match["title_eng"] ??
            match["title"] ??
            match["title_it"] ??
            anime.title;
        anime.slug = match["slug"] ?? anime.slug;
        anime.description = (match["plot"] ?? anime.description).toString();
        anime.status = match["status"] ?? anime.status;
        if (match["genres"] is List) {
          anime.genres = match["genres"];
        }
        if (match["episodes_count"] is int) {
          anime.episodesCount = match["episodes_count"];
        }
        if (match["imageurl"] is String) {
          anime.imageUrl = normalizeImageUrl(match["imageurl"]);
        }
      }

      _totalEpisodes = anime.episodesCount;
      final globalIndex = getLatestIndex();
      await _selectRangeForIndex(globalIndex);
    } catch (e) {
      setState(() {
        episodesLoading = false;
        episodesError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranges = _buildRanges();
    return CustomScrollView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _DetailsHeaderDelegate(
            anime: anime,
            heroTag: widget.heroTag,
            episodesLoading: episodesLoading,
            episodesError: episodesError,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ExpandableText(
              backgroundColor: Theme.of(context).colorScheme.background,
              boxShadow: const [],
              textWidget: Text(
                anime.description.length > 50 ? anime.description : anime.description + " " * 50,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 15,
                ),
              ).copyWith(maxLines: 3),
              arrowWidget: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              arrowLocation: ArrowLocation.bottom,
              finalArrowLocation: ArrowLocation.bottom,
              animationDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: episodesLoading
                  ? const SizedBox(
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : episodesError
                      ? Container(
                          height: 40,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(90),
                          ),
                          child: Center(
                            child: Text(
                              "Errore nel caricamento degli episodi",
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        )
                      : Obx(
                          () => InkWell(
                            borderRadius: BorderRadius.circular(90),
                            onTap: () async {
                              final globalIndex = getLatestIndex();
                              if (_isGlobalIndexInRange(globalIndex)) {
                                await _playEpisodeAtGlobalIndex(globalIndex);
                                return;
                              }
                              await _selectRangeForIndex(globalIndex, autoPlay: true);
                            },
                            child: Container(
                              height: 40,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(90),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  controller.error.value
                                      ? Icon(
                                          Icons.error,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                        )
                                      : controller.loading.value
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Icon(
                                              Icons.play_arrow,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    _resumeLabel(),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ),
        if (ranges.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ranges.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final range = ranges[index];
                    final selected = range.start == _rangeStart;
                    return ChoiceChip(
                      label: Text(range.label),
                      selected: selected,
                      onSelected: episodesLoading
                          ? null
                          : (value) async {
                              if (value && !selected) {
                                await _selectRange(range);
                              }
                            },
                    );
                  },
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: InkWell(
              onDoubleTap: () {
                _controller.animateTo(
                  _controller.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              onTap: () {
                _controller.animateTo(
                  _controller.position.minScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                episodesLoading
                    ? "Caricamento episodi..."
                    : _totalEpisodes > 0
                        ? "Episodi $_rangeStart-$_rangeEnd di $_totalEpisodes"
                        : "${anime.episodes.length} episodi disponibili",
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        if (episodesLoading)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else if (episodesError)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  "Impossibile caricare gli episodi",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index.isOdd) {
                  return Divider(
                    color: Theme.of(context).colorScheme.background,
                    height: 6,
                    thickness: 0,
                  );
                }
                final episodeIndex = index ~/ 2;
                return EpisodeTile(
                  anime: anime,
                  index: episodeIndex,
                  rangeStart: _rangeStart,
                  resumeController: resumeController,
                );
              },
              childCount: anime.episodes.isEmpty ? 0 : (anime.episodes.length * 2 - 1),
            ),
          ),
      ],
    );
  }
}

class _DetailsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AnimeClass anime;
  final Key heroTag;
  final bool episodesLoading;
  final bool episodesError;

  _DetailsHeaderDelegate({
    required this.anime,
    required this.heroTag,
    required this.episodesLoading,
    required this.episodesError,
  });

  @override
  double get minExtent => 170;

  @override
  double get maxExtent => 260;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final t = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final imageSize = lerpDouble(170, 90, t) ?? 90;
    final titleSize = lerpDouble(22, 18, t) ?? 18;
    final statusSize = lerpDouble(15, 12, t) ?? 12;
    final topPad = lerpDouble(15, 6, t) ?? 6;
    final sidePad = lerpDouble(10, 6, t) ?? 6;
    final showGenres = t < 0.55;
    final rowBottomSpacing = lerpDouble(8, 4, t) ?? 4;
    final background = Theme.of(context).colorScheme.background;

    return Container(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, topPad, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    key: UniqueKey(),
                    tag: heroTag,
                    child: CachedNetworkImage(
                      height: imageSize,
                      width: imageSize * 0.7,
                      fit: BoxFit.cover,
                      imageUrl: anime.imageUrl,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.warning_amber_rounded,
                        size: 35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: sidePad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            anime.title,
                            maxLines: t > 0.55 ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (showGenres)
                            Wrap(
                              runSpacing: 4,
                              spacing: 4,
                              children: [
                                for (var a in anime.genres)
                                  Chip(
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    labelPadding: const EdgeInsets.only(
                                      top: -6,
                                      bottom: -6,
                                      left: 5,
                                      right: 5,
                                    ),
                                    padding: const EdgeInsets.all(0),
                                    label: Text(
                                      a['name'],
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      side: const BorderSide(
                                        strokeAlign: BorderSide.strokeAlignOutside,
                                      ),
                                    ),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                  )
                              ],
                            ),
                          SizedBox(height: showGenres ? 6 : 2),
                          Text(
                            "${anime.status} - ${anime.episodesCount != 0 ? anime.episodesCount : "??"} episodi",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: statusSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: rowBottomSpacing),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DetailsHeaderDelegate oldDelegate) {
    return oldDelegate.anime != anime ||
        oldDelegate.episodesLoading != episodesLoading ||
        oldDelegate.episodesError != episodesError;
  }
}

class ResumeController extends GetxController {
  final Rx<int> index;
  final AnimeClass anime;

  ResumeController({required int index_, required this.anime}) : index = index_.obs;

  updateIndex() {
    AnimeModel animeModel = fetchAnimeModel(anime);
    index.value = animeModel.lastSeenEpisodeIndex ?? 0;

    debugPrint("updateIndex: ${index.value}");
    update();
  }
}

