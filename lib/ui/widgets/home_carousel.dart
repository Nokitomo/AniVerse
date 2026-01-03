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
  bool _userInteracting = false;

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
      });
      _startAutoPlay();
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
      final next = (_currentIndex + 1) % _items.length;
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

  void _goTo(int index) {
    if (!_controller.hasClients || _items.isEmpty) {
      return;
    }
    final clamped = index.clamp(0, _items.length - 1);
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
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final anime = _items[index];
                return InkWell(
                  onTap: () => _openAnime(anime),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: anime.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceVariant,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceVariant,
                          child: const Icon(Icons.warning_amber_rounded),
                        ),
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
                onTap: () => _goTo(_currentIndex - 1),
              ),
            ),
          if (width > 700 && _items.length > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: _CarouselArrow(
                icon: Icons.chevron_right,
                onTap: () => _goTo(_currentIndex + 1),
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
