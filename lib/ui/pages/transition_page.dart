import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:get/get.dart';

import 'package:aniverse/helper/api.dart';
import 'package:aniverse/helper/classes/anime_obj.dart';
import 'package:aniverse/settings/routes.dart';
import 'package:aniverse/ui/widgets/anime_fetch_error.dart';

class LoadingPageForAnime extends StatefulWidget {
  final AnimeClass animeObj;
  final Key heroTag;
  const LoadingPageForAnime({
    super.key,
    required this.animeObj,
    required this.heroTag,
  });

  @override
  State<LoadingPageForAnime> createState() => LoadingPageForAnimeState();
}

class LoadingPageForAnimeState extends State<LoadingPageForAnime> {
  bool error = false;
  bool _cancelled = false;
  Future<void> setUp() async {
    try {
      var response = await searchAnime(title: widget.animeObj.title);
      if (!mounted || _cancelled) return;
      push(response);
    } catch (e) {
      if (!mounted || _cancelled) return;
      Get.toNamed(
        RouteGenerator.error,
      );
    }
  }

  void push(List<dynamic> response) {
    if (!mounted || _cancelled) {
      return;
    }
    for (var anime in response) {
      if (searchToObj(anime).id == widget.animeObj.id) {
        Get.offNamed(
          RouteGenerator.animeDetail,
          arguments: [
            searchToObj(anime),
            widget.heroTag,
          ],
        );
        return;
      }
    }

    setState(() {
      error = true;
    });
  }

  @override
  void initState() {
    setUp();
    super.initState();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      extendBodyBehindAppBar: true,
      body: error
          ? LilError(animeObj: widget.animeObj, heroTag: widget.heroTag)
          : Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/single.png',
                    color: Theme.of(context).colorScheme.primary,
                    repeat: ImageRepeat.repeat,
                    scale: 30,
                    opacity: const AlwaysStoppedAnimation(0.2),
                  ),
                ),
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageHeight = (constraints.maxHeight * 0.35)
                          .clamp(180.0, 280.0)
                          .toDouble();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            key: UniqueKey(),
                            tag: widget.heroTag,
                            child: CachedNetworkImage(
                              imageUrl: widget.animeObj.imageUrl,
                              height: imageHeight,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.warning_amber_rounded,
                                size: 35,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 30,
                              right: 30,
                              top: 10,
                            ),
                            child: Text(
                              widget.animeObj.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onBackground,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          DefaultTextStyle(
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            child: AnimatedTextKit(
                              repeatForever: true,
                              animatedTexts: [
                                TypewriterAnimatedText(
                                  'Caricamento...',
                                  speed: const Duration(milliseconds: 100),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

