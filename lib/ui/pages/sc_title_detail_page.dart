import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/helper/classes/streamingcommunity_utils.dart';
import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/ui/pages/sc_player_page.dart';
import 'package:aniverse/ui/widgets/sc_episode_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ScTitleDetailPage extends StatefulWidget {
  final ScMedia media;

  const ScTitleDetailPage({
    super.key,
    required this.media,
  });

  @override
  State<ScTitleDetailPage> createState() => _ScTitleDetailPageState();
}

class _ScTitleDetailPageState extends State<ScTitleDetailPage> {
  ScTitleDetail? _detail;
  ScSeason? _currentSeason;
  bool _loading = true;
  bool _error = false;
  bool _episodesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final detail = await fetchStreamingCommunityTitleDetail(
        id: widget.media.id,
        slug: widget.media.slug,
      );
      setState(() {
        _detail = detail;
        _currentSeason = detail.loadedSeason;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _selectSeason(int number) async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    setState(() {
      _episodesLoading = true;
    });
    try {
      final season = await fetchStreamingCommunitySeasonEpisodes(
        titleId: widget.media.id,
        slug: widget.media.slug,
        seasonNumber: number,
        version: detail.version,
      );
      setState(() {
        _currentSeason = season;
        _episodesLoading = false;
      });
    } catch (_) {
      setState(() {
        _episodesLoading = false;
      });
    }
  }

  Future<void> _playEpisode(ScEpisode episode) async {
    final baseUrl = await getStreamingCommunityBaseUrl();
    final iframeEndpoint = '${baseUrl.trim()}/it/iframe/${widget.media.id}';
    final iframeUrl = await fetchStreamingCommunityIframeSrc(
      titleId: widget.media.id,
      episodeId: episode.id,
    );
    final streamUrl = await resolveStreamingCommunityStreamUrl(
      iframeUrl: iframeUrl,
      referer: '$iframeEndpoint?episode_id=${episode.id}&next_episode=1',
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScPlayerPage(
          media: widget.media,
          episodeId: episode.id,
          episodeNumber: episode.number,
          streamUrl: streamUrl,
          iframeUrl: iframeUrl,
          referer: '$iframeEndpoint?episode_id=${episode.id}&next_episode=1',
        ),
      ),
    );
  }

  Future<void> _playMovie() async {
    final baseUrl = await getStreamingCommunityBaseUrl();
    final iframeEndpoint = '${baseUrl.trim()}/it/iframe/${widget.media.id}';
    final iframeUrl = await fetchStreamingCommunityIframeSrc(
      titleId: widget.media.id,
    );
    final streamUrl = await resolveStreamingCommunityStreamUrl(
      iframeUrl: iframeUrl,
      referer: iframeEndpoint,
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScPlayerPage(
          media: widget.media,
          streamUrl: streamUrl,
          iframeUrl: iframeUrl,
          referer: iframeEndpoint,
        ),
      ),
    );
  }

  Widget _buildHeader(ScTitleDetail detail) {
    final cdnUrl = detail.cdnUrl;
    final imageUrl = buildScImageUrl(
      images: detail.title.images,
      cdnUrl: cdnUrl,
      preferredTypes: const ['cover', 'background', 'poster', 'cover_mobile'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: imageUrl.isEmpty
                ? Container(
                    color: Theme.of(context).colorScheme.background,
                    child: const Center(
                      child: Icon(Icons.warning_amber_rounded, size: 40),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Theme.of(context).colorScheme.background,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.background,
                      child: const Center(
                        child: Icon(Icons.warning_amber_rounded, size: 40),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          detail.title.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if ((detail.title.plot ?? '').isNotEmpty)
          Text(
            detail.title.plot ?? '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildSeasonSelector(ScTitleDetail detail) {
    if (detail.seasons.isEmpty) {
      return const SizedBox.shrink();
    }
    final currentNumber = _currentSeason?.number ?? detail.seasons.first.number;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: detail.seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final season = detail.seasons[index];
          return ChoiceChip(
            label: Text('Stagione ${season.number}'),
            selected: season.number == currentNumber,
            onSelected: _episodesLoading
                ? null
                : (value) {
                    if (value && season.number != currentNumber) {
                      _selectSeason(season.number);
                    }
                  },
          );
        },
      ),
    );
  }

  Widget _buildEpisodesList() {
    final season = _currentSeason;
    if (season == null || season.episodes.isEmpty) {
      return Text(
        'Nessun episodio disponibile',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: season.episodes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final episode = season.episodes[index];
        return ScEpisodeTile(
          episode: episode,
          onTap: () => _playEpisode(episode),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error || _detail == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Impossibile caricare il titolo",
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
            ),
          ),
        ),
      );
    }
    final detail = _detail!;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail.title.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildHeader(detail),
          const SizedBox(height: 16),
          if (detail.title.isMovie)
            ElevatedButton.icon(
              onPressed: _playMovie,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Guarda'),
            ),
          if (detail.title.isTv) ...[
            _buildSeasonSelector(detail),
            const SizedBox(height: 8),
            if (_episodesLoading)
              const Center(child: CircularProgressIndicator())
            else
              _buildEpisodesList(),
          ],
        ],
      ),
    );
  }
}
