import 'dart:async';
import 'package:aniverse/helper/classes/anime_obj.dart';
import 'package:aniverse/settings/routes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeHeroCarousel extends StatefulWidget {
  final Future<List<AnimeClass>> Function() loader;
  final Duration autoPlayInterval;
  final Duration resumeDelay;

  const HomeHeroCarousel({
    super.key,
    required this.loader,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.resumeDelay = const Duration(seconds: 8),
  });

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  final PageController _controller = PageController();
  final List<AnimeClass> _items = [];

  Timer? _autoTimer;
  Timer? _resumeTimer;
  bool _loading = true;
  bool _error = false;
  int _currentIndex = 0;
  int _pageIndex = 0;
  bool _userInteracting = false;
  static const int _initialPrefetchCount = 6;
  static const int _initialPrefetchBatchSize = 10;
  static const int _backgroundPrefetchBatchSize = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final items = await widget.loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
        _error = false;
        _currentIndex = 0;
        _pageIndex = items.isEmpty ? 0 : items.length * 1000;
      });
      if (_items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients) {
            _controller.jumpToPage(_pageIndex);
          }
        });
      }
      final initialPrefetch =
          _items.take(_initialPrefetchCount).toList(growable: false);
      await _prefetchCarouselImages(
        initialPrefetch,
        batchSize: _initialPrefetchBatchSize,
      );
      if (!mounted) {
        return;
      }
      _startAutoPlay();
      if (_items.length > _initialPrefetchCount) {
        final remaining = _items.skip(_initialPrefetchCount).toList();
        Future.microtask(() {
          _prefetchCarouselImages(
            remaining,
            batchSize: _backgroundPrefetchBatchSize,
          );
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _startAutoPlay() {
    _autoTimer?.cancel();
    if (_items.length < 2) {
      return;
    }
    _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (_userInteracting || !_controller.hasClients) {
        return;
      }
      _pageIndex += 1;
      final next = _pageIndex;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseAutoPlay() {
    _userInteracting = true;
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.resumeDelay, () {
      _userInteracting = false;
      _startAutoPlay();
    });
  }

  void _goTo(int delta) {
    if (!_controller.hasClients || _items.isEmpty) {
      return;
    }
    _pageIndex += delta;
    final clamped = _pageIndex;
    _controller.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _openAnime(AnimeClass anime) async {
    final heroTag = UniqueKey();
    await Get.toNamed(
      RouteGenerator.loadAnime,
      arguments: [anime, heroTag],
    );
  }

  Future<void> _prefetchCarouselImages(
    List<AnimeClass> items, {
    required int batchSize,
  }) async {
    if (!mounted || items.isEmpty) {
      return;
    }
    final providers = <ImageProvider>[];
    for (final anime in items) {
      final primary = anime.bannerUrl.isNotEmpty
          ? anime.bannerUrl
          : anime.imageUrl;
      if (primary.isNotEmpty) {
        providers.add(CachedNetworkImageProvider(primary));
      }
      final alt = anime.bannerUrl.isNotEmpty
          ? bannerFallbackUrl(anime.bannerUrl)
          : '';
      if (alt.isNotEmpty) {
        providers.add(CachedNetworkImageProvider(alt));
      }
    }

    for (var i = 0; i < providers.length; i += batchSize) {
      if (!mounted) {
        return;
      }
      final batch = providers.skip(i).take(batchSize);
      await Future.wait(
        batch.map((provider) => precacheImage(provider, context)),
      );
    }
  }

  double _carouselHeight(double width) {
    final raw = width * 0.56;
    if (raw < 190) {
      return 190;
    }
    if (raw > 260) {
      return 260;
    }
    return raw;
  }

  Widget _buildFallbackImage(AnimeClass anime, ColorScheme colorScheme) {
    if (anime.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: anime.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          color: colorScheme.surfaceVariant,
          child: const Icon(Icons.warning_amber_rounded),
        ),
      );
    }
    return Container(
      color: colorScheme.surfaceVariant,
      child: const Icon(Icons.warning_amber_rounded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = _carouselHeight(width);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error) {
      return SizedBox(
        height: height,
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text("Riprova"),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _pauseAutoPlay();
              }
              if (notification is UserScrollNotification) {
                _pauseAutoPlay();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                if (_items.isEmpty) {
                  return;
                }
                setState(() {
                  _pageIndex = index;
                  _currentIndex = index % _items.length;
                });
              },
              itemBuilder: (context, index) {
                if (_items.isEmpty) {
                  return const SizedBox.shrink();
                }
                final anime = _items[index % _items.length];
                final imageUrl = anime.bannerUrl.isNotEmpty
                    ? anime.bannerUrl
                    : anime.imageUrl;
                final bannerAlt = anime.bannerUrl.isNotEmpty
                    ? bannerFallbackUrl(anime.bannerUrl)
                    : '';
                return InkWell(
                  onTap: () => _openAnime(anime),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceVariant,
                        ),
                        errorWidget: (context, url, error) {
                          if (bannerAlt.isNotEmpty && bannerAlt != imageUrl) {
                            return CachedNetworkImage(
                              imageUrl: bannerAlt,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _buildFallbackImage(anime, colorScheme),
                            );
                          }
                          return _buildFallbackImage(anime, colorScheme);
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.05),
                              Colors.black.withOpacity(0.55),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            anime.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: width < 500 ? 22 : 28,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: List.generate(_items.length, (index) {
                final isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3,
                  width: isActive ? 20 : 12,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
          ),
          if (width > 700 && _items.length > 1)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: _CarouselArrow(
                icon: Icons.chevron_left,
                onTap: () => _goTo(-1),
              ),
            ),
          if (width > 700 && _items.length > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: _CarouselArrow(
                icon: Icons.chevron_right,
                onTap: () => _goTo(1),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrow({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: colorScheme.onSurface,
            size: 28,
          ),
        ),
      ),
    );
  }
}
