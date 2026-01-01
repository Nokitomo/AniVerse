import 'package:aniverse/helper/api.dart';
import 'package:aniverse/ui/widgets/details_content.dart';
import 'package:aniverse/ui/widgets/details_content_fragments/episode_tile.dart';
import 'package:flutter/material.dart';
import 'package:aniverse/ui/widgets/player.dart';
import 'package:get/get.dart';

import 'package:aniverse/helper/classes/anime_obj.dart';

import 'package:aniverse/services/internal_db.dart';
import 'package:aniverse/helper/models/anime_model.dart';

class EpisodePlayer extends StatefulWidget {
  final AnimeClass anime;

  final Widget child;
  final int? index;

  final LoadingThings controller;
  final ResumeController resumeController;

  final int? borderRadius;
  final double height;

  final bool resume;
  final int rangeStart;

  const EpisodePlayer({
    super.key,
    required this.child,
    required this.anime,
    this.index,
    required this.controller,
    required this.resumeController,
    this.borderRadius,
    this.height = 63,
    this.resume = false,
    this.rangeStart = 1,
  });

  @override
  State<EpisodePlayer> createState() => _EpisodePlayerState();
}

class _EpisodePlayerState extends State<EpisodePlayer> {
  late AnimeClass anime;
  late int index;

  @override
  void initState() {
    anime = widget.anime;
    index = widget.index ?? 0;

    super.initState();
  }

  void setError(bool value) {
    widget.controller.setError(value);
  }

  void setLoading(bool value) {
    widget.controller.setLoading(value);
  }

  void openPlayer(String link) async {
    await Get.to(
      () => PlayerPage(
        url: link,
        colorScheme: Theme.of(Get.context!).colorScheme,
        animeId: anime.id,
        episodeId: anime.episodes[index]['id'],
        anime: anime,
      ),
    );

    widget.controller.updateProgress();
    widget.resumeController.updateIndex();
  }

  void trackProgress() {
    var animeModel = fetchAnimeModel(anime);
    animeModel.lastSeenDate = DateTime.now();
    final globalIndex = (widget.rangeStart - 1) + index;
    animeModel.lastSeenEpisodeIndex = globalIndex;

    Get.find<ObjectBox>().store.box<AnimeModel>().put(animeModel);
    widget.resumeController.updateIndex();
  }

  Future<void> handleClick() async {
    if (anime.episodes.isEmpty) {
      setError(true);
      return;
    }

    if (widget.resume) {
      final globalIndex = widget.resumeController.index.value;
      final localIndex = globalIndex - (widget.rangeStart - 1);
      index = localIndex.clamp(0, anime.episodes.length - 1);
    }

    trackProgress();

    setLoading(true);
    setError(false);

    try {
      final episodeId = anime.episodes[index]['id'];
      final link = await fetchEpisodeStreamUrl(episodeId);
      openPlayer(link);
    } catch (e) {
      setError(true);
    } finally {
      setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.bottomLeft,
      children: [
        InkWell(
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(
            widget.borderRadius?.toDouble() ?? 0,
          ),
          onTap: () {
            handleClick();
          },
          child: widget.child,
        ),
      ],
    );
  }
}

