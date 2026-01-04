import 'dart:convert';

import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/services/internal_api.dart';
import 'package:aniverse/services/sc_webview_client.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

const String _domainsUrl =
    'https://raw.githubusercontent.com/Arrowar/SC_Domains/refs/heads/main/domains.json';
const String _defaultLocale = 'it';
const Duration _domainsCacheDuration = Duration(hours: 12);

final InternalAPI internalAPI = Get.find<InternalAPI>();

const Map<String, String> _defaultHeaders = {
  'Accept': 'application/json',
  'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36',
};

String _normalizeBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

String _withLocale(String baseUrl) {
  return '$baseUrl/$_defaultLocale';
}

String _decodeHtmlAttribute(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

String _safeSnippet(String value, int max) {
  if (value.length <= max) {
    return value;
  }
  return value.substring(0, max);
}

class _ScHttpException implements Exception {
  final int statusCode;
  final String url;

  _ScHttpException(this.statusCode, this.url);

  @override
  String toString() => 'HTTP $statusCode for $url';
}

Map<String, dynamic>? _readStreamingCommunityEntry(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map && decoded['streamingcommunity'] is Map) {
      return (decoded['streamingcommunity'] as Map).cast<String, dynamic>();
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? _buildAltDomain(String baseUrl, String altTld) {
  if (altTld.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  final parts = uri.host.split('.');
  if (parts.length < 2) {
    return null;
  }
  parts[parts.length - 1] = altTld.trim();
  final newHost = parts.join('.');
  return _normalizeBaseUrl(uri.replace(host: newHost).toString());
}

List<String> _buildBaseUrlCandidates({
  required String primary,
  Map<String, dynamic>? entry,
}) {
  final candidates = <String>[primary];
  final oldDomain = entry?['old_domain']?.toString();
  final alt = oldDomain != null ? _buildAltDomain(primary, oldDomain) : null;
  if (alt != null && alt.isNotEmpty) {
    candidates.add(alt);
  }
  return candidates.toSet().toList();
}

Map<String, dynamic> _extractDataPage(String html) {
  final match = RegExp(
    r'id="app"[^>]*data-page="([^"]+)"',
    caseSensitive: false,
  ).firstMatch(html) ??
      RegExp(
        r"id='app'[^>]*data-page='([^']+)'",
        caseSensitive: false,
      ).firstMatch(html);
  if (match == null) {
    throw Exception('Missing data-page payload');
  }
  final raw = match.group(1) ?? '';
  if (raw.isEmpty) {
    throw Exception('Empty data-page payload');
  }
  return _decodeDataPagePayload(raw);
}

Map<String, dynamic> _decodeDataPagePayload(String raw) {
  final decoded = _decodeHtmlAttribute(raw);
  final data = jsonDecode(decoded);
  if (data is! Map) {
    throw Exception('Invalid data-page payload');
  }
  return data.cast<String, dynamic>();
}

ScWebViewClient? _getScWebViewClient() {
  if (Get.isRegistered<ScWebViewClient>()) {
    return Get.find<ScWebViewClient>();
  }
  return null;
}

Future<String> _fetchBodyWithWebView({
  required String url,
  String method = 'GET',
  Map<String, String>? headers,
  Object? body,
  bool allowDomFallback = false,
}) async {
  final webViewClient = _getScWebViewClient();
  if (webViewClient == null) {
    throw Exception('StreamingCommunity WebView non pronta');
  }
  final response = await webViewClient.fetchText(
    url: url,
    method: method,
    headers: headers,
    body: body,
  );
  if (response.statusCode == 0 && allowDomFallback) {
    final raw = await webViewClient.fetchDataPageAttribute(url);
    return raw;
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _ScHttpException(response.statusCode, url);
  }
  return response.body;
}

Future<Map<String, dynamic>?> _fetchDomainsOnline() async {
  final response = await http.get(Uri.parse(_domainsUrl), headers: _defaultHeaders);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return null;
  }
  final data = jsonDecode(response.body);
  if (data is Map) {
    return data.cast<String, dynamic>();
  }
  return null;
}

Future<String> getStreamingCommunityBaseUrl() async {
  final cachedRaw = internalAPI.getKeyValue('sc_domains_cache');
  final cachedAtRaw = internalAPI.getKeyValue('sc_domains_cache_time');
  final now = DateTime.now();
  DateTime? cachedAt;
  if (cachedAtRaw.isNotEmpty) {
    cachedAt = DateTime.tryParse(cachedAtRaw);
  }
  if (cachedRaw.isNotEmpty && cachedAt != null) {
    final delta = now.difference(cachedAt);
    if (delta <= _domainsCacheDuration) {
      final entry = _readStreamingCommunityEntry(cachedRaw);
      final fullUrl = entry?['full_url']?.toString();
      if (fullUrl != null && fullUrl.isNotEmpty) {
        return _normalizeBaseUrl(fullUrl);
      }
    }
  }

  try {
    final domains = await _fetchDomainsOnline();
    if (domains != null && domains['streamingcommunity'] is Map) {
      final entry = domains['streamingcommunity'] as Map;
      final fullUrl = entry['full_url']?.toString();
      if (fullUrl != null && fullUrl.isNotEmpty) {
        internalAPI.setKeyValue('sc_domains_cache', jsonEncode(domains));
        internalAPI.setKeyValue('sc_domains_cache_time', now.toIso8601String());
        return _normalizeBaseUrl(fullUrl);
      }
    }
  } catch (_) {
    // ignore network errors and fall back
  }

  if (cachedRaw.isNotEmpty) {
    final entry = _readStreamingCommunityEntry(cachedRaw);
    final fullUrl = entry?['full_url']?.toString();
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return _normalizeBaseUrl(fullUrl);
    }
  }

  return 'https://streamingcommunityz.gold';
}

Future<Map<String, dynamic>> _fetchInertiaDataPage(
  String url, {
  Map<String, String>? headers,
}) async {
  final response = await http.get(
    Uri.parse(url),
    headers: headers ?? _defaultHeaders,
  );
  if (response.statusCode == 403) {
    debugPrint('SC home HTTP 403 from $url');
    final raw = await _fetchBodyWithWebView(
      url: url,
      allowDomFallback: true,
    );
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('<') || trimmed.contains('<html')) {
      try {
        return _extractDataPage(raw);
      } catch (error) {
        debugPrint(
          'SC html snippet ${_safeSnippet(raw, 260)}',
        );
        rethrow;
      }
    }
    return _decodeDataPagePayload(raw);
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _ScHttpException(response.statusCode, url);
  }

  final body = response.body;
  if (body.trim().startsWith('{')) {
    final data = jsonDecode(body);
    if (data is! Map) {
      throw Exception('Invalid inertia response');
    }
    return data.cast<String, dynamic>();
  }

  try {
    return _extractDataPage(body);
  } catch (error) {
    debugPrint('SC html snippet ${_safeSnippet(body, 260)}');
    rethrow;
  }
}

Future<ScHomePayload> fetchStreamingCommunityHome() async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final entry =
      _readStreamingCommunityEntry(internalAPI.getKeyValue('sc_domains_cache'));
  final candidates = _buildBaseUrlCandidates(primary: baseUrl, entry: entry);
  for (final candidate in candidates) {
    try {
      final data = await _fetchInertiaDataPage('$candidate/');
      final props = data['props'] is Map
          ? (data['props'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final slidersRaw = props['sliders'];
      final slideBannersRaw = props['slideBanners'];

      final sliders = slidersRaw is List
          ? slidersRaw
              .whereType<Map>()
              .map((item) =>
                  ScHomeSlider.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <ScHomeSlider>[];
      final slideBanners = slideBannersRaw is List
          ? slideBannersRaw
              .whereType<Map>()
              .map((item) =>
                  ScSlideBanner.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <ScSlideBanner>[];
      final genres = props['genres'] is List ? props['genres'] as List : const [];

      return ScHomePayload(
        version: data['version']?.toString() ?? '',
        appUrl: props['app_url']?.toString() ?? candidate,
        cdnUrl: props['cdn_url']?.toString() ?? '',
        scwsUrl: props['scws_url']?.toString() ?? '',
        sliders: sliders,
        slideBanners: slideBanners,
        genres: genres,
        raw: data,
      );
    } on _ScHttpException catch (error) {
      if (error.statusCode == 403) {
        continue;
      }
      debugPrint('SC home HTTP ${error.statusCode} from $candidate');
      rethrow;
    } catch (error) {
      debugPrint('SC home parse error from $candidate: $error');
      throw Exception('Parsing fallito per $candidate');
    }
  }

  throw Exception('StreamingCommunity home bloccata (403)');
}

Future<ScHomeSlider> fetchStreamingCommunitySlider(String name) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final url = '$baseUrl/api/browse/$name';
  final response = await http.get(
    Uri.parse(url),
    headers: _defaultHeaders,
  );
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(url: url);
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for api/browse/$name');
  } else {
    body = response.body;
  }
  final data = jsonDecode(body);
  if (data is! Map) {
    throw Exception('Invalid browse response');
  }
  return ScHomeSlider.fromJson(data.cast<String, dynamic>());
}

Future<ScPagedResult<ScMedia>> searchStreamingCommunityTitles({
  required String query,
  int page = 1,
}) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final uri = Uri.parse('$baseUrl/api/search').replace(queryParameters: {
    'q': query,
    if (page > 1) 'page': page.toString(),
  });
  final response = await http.get(uri, headers: _defaultHeaders);
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(url: uri.toString());
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for api/search');
  } else {
    body = response.body;
  }
  final data = jsonDecode(body);
  if (data is! Map) {
    throw Exception('Invalid search response');
  }
  final list = data['data'] is List ? data['data'] as List : const [];
  final items = list.whereType<Map>().map((item) => ScMedia.fromJson(item.cast<String, dynamic>())).toList();
  return ScPagedResult(
    data: items,
    currentPage: data['current_page'] is int ? data['current_page'] as int : int.tryParse('${data['current_page']}') ?? 1,
    lastPage: data['last_page'] is int ? data['last_page'] as int : int.tryParse('${data['last_page']}') ?? 1,
    perPage: data['per_page'] is int ? data['per_page'] as int : int.tryParse('${data['per_page']}') ?? items.length,
    total: data['total'] is int ? data['total'] as int : int.tryParse('${data['total']}') ?? items.length,
  );
}

Future<List<ScMedia>> fetchStreamingCommunityArchive({Map<String, String>? query}) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final uri = Uri.parse('$baseUrl/api/archive').replace(queryParameters: query);
  final response = await http.get(uri, headers: _defaultHeaders);
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(url: uri.toString());
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for api/archive');
  } else {
    body = response.body;
  }
  final data = jsonDecode(body);
  if (data is! Map) {
    throw Exception('Invalid archive response');
  }
  final list = data['titles'] is List ? data['titles'] as List : const [];
  return list.whereType<Map>().map((item) => ScMedia.fromJson(item.cast<String, dynamic>())).toList();
}

Future<ScTitlePreview> fetchStreamingCommunityTitlePreview(int id) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final url = '$baseUrl/api/titles/preview/$id';
  final headers = {
    ..._defaultHeaders,
    'X-Requested-With': 'XMLHttpRequest',
  };
  final response = await http.post(
    Uri.parse(url),
    headers: headers,
  );
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(
      url: url,
      method: 'POST',
      headers: headers,
    );
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for api/titles/preview/$id');
  } else {
    body = response.body;
  }
  final data = jsonDecode(body);
  if (data is! Map) {
    throw Exception('Invalid title preview response');
  }
  return ScTitlePreview.fromJson(data.cast<String, dynamic>());
}

Future<ScTitleDetail> fetchStreamingCommunityTitleDetail({
  required int id,
  required String slug,
}) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final url = '${_withLocale(baseUrl)}/titles/$id-$slug';
  final data = await _fetchInertiaDataPage(url);
  final props = data['props'] is Map ? (data['props'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  final titleRaw = props['title'] is Map ? (props['title'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  final seasonsRaw = titleRaw['seasons'] is List ? titleRaw['seasons'] as List : const [];
  final loadedRaw = props['loadedSeason'] is Map ? (props['loadedSeason'] as Map).cast<String, dynamic>() : null;

  final title = ScMedia.fromJson(titleRaw);
  final seasons = seasonsRaw.whereType<Map>().map((item) {
    return ScSeason.fromJson(item.cast<String, dynamic>());
  }).toList();

  ScSeason? loadedSeason;
  if (loadedRaw != null) {
    final episodesRaw = loadedRaw['episodes'] is List ? loadedRaw['episodes'] as List : const [];
    final episodes = episodesRaw.whereType<Map>().map((item) {
      return ScEpisode.fromJson(item.cast<String, dynamic>());
    }).toList();
    loadedSeason = ScSeason.fromJson(loadedRaw, episodes: episodes);
  }

  return ScTitleDetail(
    title: title,
    seasons: seasons,
    loadedSeason: loadedSeason,
    version: data['version']?.toString() ?? '',
    cdnUrl: props['cdn_url']?.toString() ?? '',
    scwsUrl: props['scws_url']?.toString() ?? '',
    raw: data,
  );
}

Future<ScSeason> fetchStreamingCommunitySeasonEpisodes({
  required int titleId,
  required String slug,
  required int seasonNumber,
  required String version,
}) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final url = '${_withLocale(baseUrl)}/titles/$titleId-$slug/season-$seasonNumber';
  final data = await _fetchInertiaDataPage(
    url,
    headers: {
      ..._defaultHeaders,
      'X-Inertia': 'true',
      if (version.isNotEmpty) 'X-Inertia-Version': version,
    },
  );
  final props = data['props'] is Map ? (data['props'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  final loadedRaw = props['loadedSeason'] is Map ? (props['loadedSeason'] as Map).cast<String, dynamic>() : <String, dynamic>{};
  final episodesRaw = loadedRaw['episodes'] is List ? loadedRaw['episodes'] as List : const [];
  final episodes = episodesRaw.whereType<Map>().map((item) {
    return ScEpisode.fromJson(item.cast<String, dynamic>());
  }).toList();

  return ScSeason.fromJson(loadedRaw, episodes: episodes);
}

Future<String> fetchStreamingCommunityIframeSrc({
  required int titleId,
  int? episodeId,
}) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final uri = Uri.parse('${_withLocale(baseUrl)}/iframe/$titleId').replace(queryParameters: {
    if (episodeId != null) 'episode_id': episodeId.toString(),
    if (episodeId != null) 'next_episode': '1',
  });
  final response = await http.get(uri, headers: _defaultHeaders);
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(
      url: uri.toString(),
      allowDomFallback: true,
    );
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for iframe');
  } else {
    body = response.body;
  }
  final match = RegExp(r'<iframe[^>]+src="([^"]+)"', caseSensitive: false).firstMatch(body);
  if (match == null) {
    throw Exception('Missing iframe src');
  }
  final raw = match.group(1) ?? '';
  if (raw.isEmpty) {
    throw Exception('Empty iframe src');
  }
  return _decodeHtmlAttribute(raw);
}

String? _extractM3u8Url(String html) {
  final match = RegExp(
    "(https?://[^\\s'\"<>]+m3u8[^\\s'\"<>]*)",
    caseSensitive: false,
  ).firstMatch(html);
  return match?.group(1);
}

Map<String, String> _extractMasterPlaylistMeta(String html) {
  final meta = <String, String>{};
  final urlMatch = RegExp(
    "url\\s*:\\s*['\\\"]([^'\\\"]+)",
    caseSensitive: false,
  ).firstMatch(html);
  final tokenMatch = RegExp(
    "token\\s*:\\s*['\\\"]([^'\\\"]+)",
    caseSensitive: false,
  ).firstMatch(html);
  final expiresMatch = RegExp(
    "expires\\s*:\\s*['\\\"]?(\\d+)",
    caseSensitive: false,
  ).firstMatch(html);
  if (urlMatch != null) {
    meta['url'] = urlMatch.group(1) ?? '';
  }
  if (tokenMatch != null) {
    meta['token'] = tokenMatch.group(1) ?? '';
  }
  if (expiresMatch != null) {
    meta['expires'] = expiresMatch.group(1) ?? '';
  }
  return meta;
}

bool _extractCanPlayFhd(String html) {
  final match = RegExp(
    'canPlayFHD\\s*=\\s*(true|false|1|0)',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null) {
    return false;
  }
  final value = match.group(1)?.toLowerCase() ?? 'false';
  return value == 'true' || value == '1';
}

Future<String> resolveStreamingCommunityStreamUrl({
  required String iframeUrl,
  required String referer,
}) async {
  final headers = {
    ..._defaultHeaders,
    'Referer': referer,
    'Origin': Uri.parse(referer).origin,
  };
  final response = await http.get(
    Uri.parse(iframeUrl),
    headers: headers,
  );
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(
      url: iframeUrl,
      headers: headers,
      allowDomFallback: true,
    );
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for embed');
  } else {
    body = response.body;
  }
  final direct = _extractM3u8Url(body);
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final meta = _extractMasterPlaylistMeta(body);
  final url = meta['url'];
  if (url == null || url.isEmpty) {
    throw Exception('Missing master playlist url');
  }
  final parsed = Uri.parse(url);
  final queryParams = Map<String, String>.from(parsed.queryParameters);
  if (meta['token'] != null && meta['token']!.isNotEmpty) {
    queryParams['token'] = meta['token']!;
  }
  if (meta['expires'] != null && meta['expires']!.isNotEmpty) {
    queryParams['expires'] = meta['expires']!;
  }
  if (_extractCanPlayFhd(body)) {
    queryParams['h'] = '1';
  }
  final normalized = parsed.replace(queryParameters: queryParams);
  return normalized.toString();
}

Future<Map<String, dynamic>> fetchStreamingCommunityVideoInfo(int videoId) async {
  final baseUrl = await getStreamingCommunityBaseUrl();
  final url = '$baseUrl/api/video/$videoId';
  final response = await http.get(
    Uri.parse(url),
    headers: _defaultHeaders,
  );
  String body;
  if (response.statusCode == 403) {
    body = await _fetchBodyWithWebView(url: url);
  } else if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for api/video/$videoId');
  } else {
    body = response.body;
  }
  final data = jsonDecode(body);
  if (data is! Map) {
    throw Exception('Invalid video info response');
  }
  return data.cast<String, dynamic>();
}
