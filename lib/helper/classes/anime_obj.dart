import 'package:aniverse/helper/models/anime_model.dart';

class AnimeClass {
  String title;
  String imageUrl;
  int id;
  String description;
  List episodes;
  String status;
  List genres;
  int episodesCount;
  String slug;
  String type;
  String studio;
  int? year;
  String episodeLabel;
  String progressLabel;

  DateTime? lastSeen;

  AnimeClass({
    required this.title,
    required this.imageUrl,
    required this.id,
    required this.description,
    required this.episodes,
    required this.status,
    required this.genres,
    required this.episodesCount,
    required this.slug,
    this.type = '',
    this.studio = '',
    this.year,
    this.lastSeen,
    this.episodeLabel = '',
    this.progressLabel = '',
  });

  AnimeModel getModel() {
    AnimeModel obj = AnimeModel();

    obj.title = title;
    obj.imageUrl = imageUrl;
    obj.id = id;
    obj.lastSeenDate = DateTime.now();

    return obj;
  }

  get toModel => getModel();
}

String normalizeImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return '';
  }

  Uri? uri;
  try {
    uri = Uri.parse(url);
  } catch (_) {
    return url;
  }

  final host = (uri.host).toLowerCase();
  if (host.contains('animeworld.so')) {
    final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (filename.isNotEmpty) {
      return 'https://img.animeunity.so/anime/$filename';
    }
  }

  return url;
}

AnimeClass searchToObj(dynamic json) {
  final episodes = json['episodes'];
  final genres = json['genres'];
  return AnimeClass(
      title: json['title'] ?? json['title_eng'] ?? json['title_it'] ?? '',
      imageUrl: normalizeImageUrl(json['imageurl']),
      id: json['id'] ?? 0,
      description: (json['plot'] ?? '').toString(), //archivio
      episodes: episodes is List ? episodes : [],
      status: json['status'] ?? '',
      genres: genres is List ? genres : [],
      episodesCount: json['episodes_count'] ?? 0,
      slug: json['slug'] ?? '',
      type: json['type'] ?? '',
      studio: json['studio'] ?? '',
      year: int.tryParse((json['date'] ?? '').toString()));
}

AnimeClass popularToObj(dynamic json) {
  return AnimeClass(
      title: json['title'] ?? json['title_eng'] ?? json['title_it'] ?? '',
      imageUrl: normalizeImageUrl(json['imageurl']),
      id: json['id'] ?? 0,
      description: (json['plot'] ?? '').toString(), //popolari
      episodes: [],
      status: json['status'] ?? '',
      genres: [],
      episodesCount: json['episodes_count'] ?? 0,
      slug: json['slug'] ?? '',
      type: json['type'] ?? '',
      studio: json['studio'] ?? '',
      year: int.tryParse((json['date'] ?? '').toString()));
}

String? _episodeLabelFromValue(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  final match = RegExp(r'\d+').firstMatch(text);
  if (match == null) {
    return null;
  }
  return 'Ep. ${match.group(0)}';
}

String? _episodeLabelFromEpisodes(List episodes) {
  int? maxValue;
  for (final ep in episodes) {
    if (ep is Map) {
      final raw = ep['number'] ?? ep['episode'];
      final label = _episodeLabelFromValue(raw);
      if (label != null) {
        final num = int.tryParse(label.replaceAll(RegExp(r'\\D'), ''));
        if (num != null && (maxValue == null || num > maxValue)) {
          maxValue = num;
        }
      }
    }
  }
  if (maxValue == null) {
    return null;
  }
  return 'Ep. $maxValue';
}

String? _episodeLabelFromMap(Map json) {
  const keys = [
    'episode',
    'episode_number',
    'ep_number',
    'episode_num',
    'last_episode',
    'last_episode_number',
    'last_episode_num',
  ];
  for (final key in keys) {
    if (!json.containsKey(key)) {
      continue;
    }
    final value = json[key];
    if (value is Map) {
      final nested = _episodeLabelFromValue(
        value['number'] ?? value['episode'] ?? value['id'],
      );
      if (nested != null) {
        return nested;
      }
    }
    final label = _episodeLabelFromValue(value);
    if (label != null) {
      return label;
    }
  }
  return null;
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

AnimeClass latestToObj(dynamic json) {
  String? episodeLabel = _episodeLabelFromMap(json);
  if (episodeLabel == null) {
    final episodeObj = json['episode'];
    if (episodeObj is Map) {
      episodeLabel = _episodeLabelFromValue(
        episodeObj['number'] ?? episodeObj['episode'] ?? episodeObj['id'],
      );
    }
  }
  return AnimeClass(
      title: json["anime"]['title'] ?? json["anime"]['title_eng'] ?? json["anime"]['title_it'] ?? '',
      imageUrl: normalizeImageUrl(json["anime"]['imageurl']),
      id: json['anime']['id'] ?? 0,
      description: (json["anime"]['plot'] ?? '').toString(), //ultimi usciti
      episodes: [],
      status: json["anime"]['status'] ?? '',
      genres: [],
      episodesCount: json["anime"]['episodes_count'] ?? 0,
      slug: json["anime"]['slug'] ?? '',
      type: json["anime"]['type'] ?? '',
      studio: json["anime"]['studio'] ?? '',
      year: int.tryParse((json["anime"]['date'] ?? '').toString()),
      episodeLabel: episodeLabel ?? '');
}

AnimeClass calendarToObj(dynamic json) {
  final obj = searchToObj(json);
  String? episodeLabel = _episodeLabelFromMap(json);
  final episodes = json['episodes'];
  if (episodes is List) {
    episodeLabel ??= _episodeLabelFromEpisodes(episodes);
  }
  if (episodeLabel == null) {
    final fallback =
        json['episodes_count'] ?? json['real_episodes_count'] ?? json['episode_count'];
    episodeLabel = _episodeLabelFromValue(fallback);
  }
  return AnimeClass(
    title: obj.title,
    imageUrl: obj.imageUrl,
    id: obj.id,
    description: obj.description,
    episodes: obj.episodes,
    status: obj.status,
    genres: obj.genres,
    episodesCount: obj.episodesCount,
    slug: obj.slug,
    type: obj.type,
    studio: obj.studio,
    year: obj.year,
    episodeLabel: episodeLabel ?? '',
  );
}

AnimeClass modelToObj(AnimeModel model) {
  String progressLabel = '';
  String episodeLabel = '';

  model.decodeStr();

  final lastIndex = model.lastSeenEpisodeIndex;
  if (lastIndex != null && lastIndex >= 0) {
    episodeLabel = 'Ep. ${lastIndex + 1}';
  }

  int? currentSeconds;
  final lastEpisodeId = model.episodes['_lastEpisodeId'];
  if (lastEpisodeId != null) {
    final value = model.episodes[lastEpisodeId.toString()];
    if (value is List && value.isNotEmpty) {
      final raw = value[0];
      if (raw is int) {
        currentSeconds = raw;
      }
    }
  }
  if (currentSeconds == null) {
    int maxSeconds = -1;
    for (final entry in model.episodes.entries) {
      final key = entry.key.toString();
      if (key == '_lastEpisodeId') {
        continue;
      }
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        final raw = value[0];
        if (raw is int && raw > maxSeconds) {
          maxSeconds = raw;
        }
      }
    }
    if (maxSeconds >= 0) {
      currentSeconds = maxSeconds;
    }
  }

  if (currentSeconds != null) {
    progressLabel = _formatSeconds(currentSeconds);
  }

  return AnimeClass(
    title: model.title ?? '',
    imageUrl: normalizeImageUrl(model.imageUrl),
    id: model.id ?? 0,
    description: '',
    episodes: [],
    status: '',
    genres: [],
    episodesCount: 0,
    slug: '',
    type: '',
    studio: '',
    year: null,
    lastSeen: model.lastSeenDate,
    episodeLabel: episodeLabel,
    progressLabel: progressLabel,
  );
}


