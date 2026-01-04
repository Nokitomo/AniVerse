class ScImage {
  final String filename;
  final String type;
  final String? lang;

  const ScImage({
    required this.filename,
    required this.type,
    this.lang,
  });

  factory ScImage.fromJson(Map<String, dynamic> json) {
    return ScImage(
      filename: json['filename']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      lang: json['lang']?.toString(),
    );
  }
}

class ScEpisode {
  final int id;
  final int number;
  final String name;
  final int duration;
  final int? scwsId;
  final String? quality;
  final List<ScImage> images;
  final Map<String, dynamic> raw;

  const ScEpisode({
    required this.id,
    required this.number,
    required this.name,
    required this.duration,
    required this.images,
    required this.raw,
    this.scwsId,
    this.quality,
  });

  factory ScEpisode.fromJson(Map<String, dynamic> json) {
    return ScEpisode(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      number: json['number'] is int ? json['number'] as int : int.tryParse('${json['number']}') ?? 0,
      name: json['name']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] as int : int.tryParse('${json['duration']}') ?? 0,
      scwsId: json['scws_id'] is int ? json['scws_id'] as int : int.tryParse('${json['scws_id']}'),
      quality: json['quality']?.toString(),
      images: _parseImages(json['images']),
      raw: json,
    );
  }
}

class ScSeason {
  final int id;
  final int number;
  final String name;
  final int? episodesCount;
  final List<ScEpisode> episodes;
  final Map<String, dynamic> raw;

  const ScSeason({
    required this.id,
    required this.number,
    required this.name,
    required this.episodes,
    required this.raw,
    this.episodesCount,
  });

  factory ScSeason.fromJson(Map<String, dynamic> json, {List<ScEpisode>? episodes}) {
    return ScSeason(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      number: json['number'] is int ? json['number'] as int : int.tryParse('${json['number']}') ?? 0,
      name: json['name']?.toString() ?? 'Season',
      episodesCount: json['episodes_count'] is int
          ? json['episodes_count'] as int
          : int.tryParse('${json['episodes_count']}'),
      episodes: episodes ?? const [],
      raw: json,
    );
  }

  ScSeason copyWith({List<ScEpisode>? episodes}) {
    return ScSeason(
      id: id,
      number: number,
      name: name,
      episodesCount: episodesCount,
      episodes: episodes ?? this.episodes,
      raw: raw,
    );
  }
}

class ScMedia {
  final int id;
  final String slug;
  final String name;
  final String type;
  final String? lastAirDate;
  final int seasonsCount;
  final String? quality;
  final String? plot;
  final double? score;
  final List<dynamic> genres;
  final List<ScImage> images;
  final Map<String, dynamic> raw;

  const ScMedia({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    required this.seasonsCount,
    required this.genres,
    required this.images,
    required this.raw,
    this.lastAirDate,
    this.quality,
    this.plot,
    this.score,
  });

  bool get isMovie => type == 'movie';
  bool get isTv => type == 'tv';

  factory ScMedia.fromJson(Map<String, dynamic> json) {
    final scoreValue = json['score'];
    return ScMedia(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      lastAirDate: json['last_air_date']?.toString(),
      seasonsCount: json['seasons_count'] is int
          ? json['seasons_count'] as int
          : int.tryParse('${json['seasons_count']}') ?? 0,
      quality: json['quality']?.toString(),
      plot: json['plot']?.toString(),
      score: scoreValue is num ? scoreValue.toDouble() : double.tryParse('${json['score']}'),
      genres: json['genres'] is List ? json['genres'] as List : const [],
      images: _parseImages(json['images']),
      raw: json,
    );
  }
}

class ScHomeSlider {
  final String name;
  final String label;
  final List<ScMedia> titles;

  const ScHomeSlider({
    required this.name,
    required this.label,
    required this.titles,
  });

  factory ScHomeSlider.fromJson(Map<String, dynamic> json) {
    final titles = json['titles'];
    final List<ScMedia> parsedTitles = titles is List
        ? titles.whereType<Map>().map((item) => ScMedia.fromJson(item.cast<String, dynamic>())).toList()
        : const [];
    return ScHomeSlider(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      titles: parsedTitles,
    );
  }
}

class ScSlideBanner {
  final int id;
  final String title;
  final String imageUrl;
  final String link;
  final bool isActive;
  final bool isAd;
  final Map<String, dynamic> raw;

  const ScSlideBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.link,
    required this.isActive,
    required this.isAd,
    required this.raw,
  });

  factory ScSlideBanner.fromJson(Map<String, dynamic> json) {
    return ScSlideBanner(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      isActive: json['is_active'] == true,
      isAd: json['is_ad'] == true,
      raw: json,
    );
  }
}

class ScHomePayload {
  final String version;
  final String appUrl;
  final String cdnUrl;
  final String scwsUrl;
  final List<ScHomeSlider> sliders;
  final List<ScSlideBanner> slideBanners;
  final List<dynamic> genres;
  final Map<String, dynamic> raw;

  const ScHomePayload({
    required this.version,
    required this.appUrl,
    required this.cdnUrl,
    required this.scwsUrl,
    required this.sliders,
    required this.slideBanners,
    required this.genres,
    required this.raw,
  });
}

class ScPagedResult<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const ScPagedResult({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });
}

class ScTitlePreview {
  final int id;
  final String type;
  final String? plot;
  final String? quality;
  final int? runtime;
  final List<dynamic> genres;
  final List<ScImage> images;
  final Map<String, dynamic> raw;

  const ScTitlePreview({
    required this.id,
    required this.type,
    required this.genres,
    required this.images,
    required this.raw,
    this.plot,
    this.quality,
    this.runtime,
  });

  factory ScTitlePreview.fromJson(Map<String, dynamic> json) {
    return ScTitlePreview(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      type: json['type']?.toString() ?? '',
      plot: json['plot']?.toString(),
      quality: json['quality']?.toString(),
      runtime: json['runtime'] is int ? json['runtime'] as int : int.tryParse('${json['runtime']}'),
      genres: json['genres'] is List ? json['genres'] as List : const [],
      images: _parseImages(json['images']),
      raw: json,
    );
  }
}

class ScTitleDetail {
  final ScMedia title;
  final List<ScSeason> seasons;
  final ScSeason? loadedSeason;
  final String version;
  final String cdnUrl;
  final String scwsUrl;
  final Map<String, dynamic> raw;

  const ScTitleDetail({
    required this.title,
    required this.seasons,
    required this.loadedSeason,
    required this.version,
    required this.cdnUrl,
    required this.scwsUrl,
    required this.raw,
  });
}

List<ScImage> _parseImages(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((item) {
      return ScImage.fromJson(item.cast<String, dynamic>());
    }).toList();
  }
  return const [];
}
