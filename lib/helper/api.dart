import 'package:aniverse/helper/classes/anime_obj.dart';
import 'package:aniverse/services/internal_api.dart';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'dart:async';
import 'dart:convert';
import 'package:aniverse/helper/models/anime_model.dart';
import 'package:aniverse/objectbox.g.dart';
import 'package:aniverse/services/internal_db.dart';
import 'package:get/get.dart';

Box objBox = Get.find<ObjectBox>().store.box<AnimeModel>();
InternalAPI internalAPI = Get.find<InternalAPI>();

const String _baseHost = "https://www.animeunity.so";
const String _baseHostNoWww = "https://animeunity.so";
const Map<String, String> _defaultHeaders = {
  "Accept": "application/json",
  "User-Agent":
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
};

class _AnimeunitySession {
  final String? xsrfToken;
  final String? session;

  const _AnimeunitySession({required this.xsrfToken, required this.session});

  String get cookieHeader {
    final parts = <String>[];
    if (xsrfToken != null && xsrfToken!.isNotEmpty) {
      parts.add("XSRF-TOKEN=$xsrfToken");
    }
    if (session != null && session!.isNotEmpty) {
      parts.add("animeunity_session=$session");
    }
    return parts.join("; ");
  }
}

String? _extractCookieValue(String raw, String name) {
  final match = RegExp("$name=([^;]+)").firstMatch(raw);
  return match?.group(1);
}

Future<_AnimeunitySession> _getAnimeunitySession() async {
  try {
    final response = await http.get(
      Uri.parse("$_baseHost/"),
      headers: _defaultHeaders,
    );
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) {
      return const _AnimeunitySession(xsrfToken: null, session: null);
    }
    final xsrf = _extractCookieValue(raw, "XSRF-TOKEN");
    final session = _extractCookieValue(raw, "animeunity_session");
    return _AnimeunitySession(
      xsrfToken: xsrf != null ? Uri.decodeComponent(xsrf) : null,
      session: session,
    );
  } catch (_) {
    return const _AnimeunitySession(xsrfToken: null, session: null);
  }
}

Map<String, String> _buildSessionHeaders(_AnimeunitySession session) {
  final headers = <String, String>{
    ..._defaultHeaders,
    "Origin": _baseHost,
    "Referer": "$_baseHost/",
  };
  if (session.xsrfToken != null && session.xsrfToken!.isNotEmpty) {
    headers["X-XSRF-TOKEN"] = session.xsrfToken!;
  }
  final cookie = session.cookieHeader;
  if (cookie.isNotEmpty) {
    headers["Cookie"] = cookie;
  }
  return headers;
}

String _decodeHtmlAttribute(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

Future<Document> makeRequestAndGetDocument(String url) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: _defaultHeaders,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("HTTP ${response.statusCode} for $url");
    }
    if (response.body.trim().isEmpty) {
      throw Exception("Empty response for $url");
    }
    return parse(response.body);
  } catch (e) {
    throw Exception("Request failed for $url: $e");
  }
}

Future<List<Element>> getElements(
  String tagName, {
  int maxTry = 10,
  required String url,
}) async {
  try {
    Document document = await makeRequestAndGetDocument(url);
    List<Element> elements = document.getElementsByTagName(tagName);
    int i = 0;
    while (elements.isEmpty && i < maxTry) {
      document = await makeRequestAndGetDocument(url);
      elements = document.getElementsByTagName(tagName);
      i++;
    }
    if (elements.isEmpty) {
      throw Exception("No <$tagName> elements found at $url");
    }
    return elements;
  } catch (e) {
    throw Exception("Failed to load elements from $url: $e");
  }
}

Future<String?> fetchAnimeBannerUrl({
  required int animeId,
  required String slug,
}) async {
  if (animeId <= 0 || slug.trim().isEmpty) {
    return null;
  }
  final url = "$_baseHost/anime/$animeId-$slug";

  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _defaultHeaders,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }
      final body = response.body;
      if (body.trim().isEmpty) {
        continue;
      }

      final document = parse(body);
      final candidates = document.getElementsByTagName('video-player');
      final element = candidates.firstWhere(
        (el) => el.attributes.containsKey('anime'),
        orElse: () => candidates.isNotEmpty ? candidates.first : Element.tag('video-player'),
      );
      final raw = element.attributes['anime'];
      if (raw != null && raw.isNotEmpty) {
        final decoded = _decodeHtmlAttribute(raw);
        final data = jsonDecode(decoded);
        if (data is Map && data['imageurl_cover'] is String) {
          final value = (data['imageurl_cover'] as String).trim();
          if (value.isEmpty) {
            return '';
          }
          return normalizeBannerUrl(value);
        }
      }

      final direct = RegExp(
        r'imageurl_cover\\\":\\\"([^\\\"]+)',
      ).firstMatch(body);
      if (direct != null) {
        final value = direct.group(1)?.trim() ?? '';
        if (value.isEmpty) {
          return '';
        }
        final normalized = value.replaceAll('\\/', '/');
        if (normalized.startsWith('http')) {
          return normalizeBannerUrl(normalized);
        }
        try {
          final decoded = jsonDecode('"$value"');
          final decodedValue = decoded.toString().trim();
          return decodedValue.isEmpty ? '' : normalizeBannerUrl(decodedValue);
        } catch (_) {
          return null;
        }
      }
      final escaped = RegExp(
        r'imageurl_cover&quot;:&quot;([^&]+)&quot;',
      ).firstMatch(body);
      if (escaped != null) {
        final value = escaped.group(1)?.trim() ?? '';
        return value.isEmpty ? '' : normalizeBannerUrl(value);
      }
    } catch (_) {
      // retry once
    }
  }
  return null;
}

Future<Map<String, dynamic>> fetchArchivioMeta() async {
  final document = await makeRequestAndGetDocument(
    "$_baseHost/archivio?hidebar=true",
  );
  final elements = document.getElementsByTagName('archivio');
  if (elements.isEmpty) {
    throw Exception("Missing archivio tag");
  }

  final element = elements.first;
  final rawGenres = element.attributes['all_genres'] ?? '[]';
  final rawOldest = element.attributes['anime_oldest_date'] ?? '';
  final rawTotal = element.attributes['tot_count'] ?? '';

  final genresDecoded = _decodeHtmlAttribute(rawGenres);
  final List genres = jsonDecode(genresDecoded);
  final oldestYear = int.tryParse(rawOldest) ?? DateTime.now().year;
  final total = int.tryParse(rawTotal) ?? 0;

  return {
    'genres': genres,
    'oldestYear': oldestYear,
    'total': total,
  };
}

Future<Map<String, dynamic>> fetchArchivioAnimes({
  String? title,
  String? type,
  int? year,
  String? order,
  String? status,
  List<Map<String, dynamic>>? genres,
  int offset = 0,
  bool dubbed = false,
  String? season,
}) async {
  final session = await _getAnimeunitySession();
  final headers = _buildSessionHeaders(session);

  final payload = {
    "title": title?.trim().isNotEmpty == true ? title!.trim() : false,
    "type": type ?? false,
    "year": year ?? false,
    "order": order ?? false,
    "status": status ?? false,
    "genres": genres ?? false,
    "offset": offset,
    "dubbed": dubbed,
    "season": season ?? false,
  };

  final response = await http.post(
    Uri.parse("$_baseHost/archivio/get-animes"),
    headers: {
      ...headers,
      "Content-Type": "application/json",
    },
    body: jsonEncode(payload),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception("HTTP ${response.statusCode} for archivio/get-animes");
  }

  final data = jsonDecode(response.body);
  if (data is! Map) {
    throw Exception("Invalid archivio response");
  }

  return {
    'records': data['records'] ?? [],
    'total': data['tot'] ?? 0,
  };
}

Future<List> latestAnime() async {
  List<Element> elements = await getElements(
    'layout-items',
    url: "$_baseHostNoWww/",
  );

  var data = elements[0].attributes['items-json'];
  if (data == null || data.isEmpty) {
    throw Exception("Missing items-json attribute");
  }
  var json = jsonDecode(data);
  return json['data'];
}

Future<List> popularAnime() async {
  List<Element> elements = await getElements(
    'top-anime',
    url: "$_baseHost/top-anime?popular=true",
  );

  var data = elements[0].attributes['animes'];
  if (data == null || data.isEmpty) {
    throw Exception("Missing animes attribute");
  }
  var json = jsonDecode(data);
  return json['data'];
}

Future<List> fetchLatestAnimePage({int page = 1}) async {
  final suffix = page > 1 ? "?page=$page" : "";
  List<Element> elements = await getElements(
    'layout-items',
    url: "$_baseHostNoWww/$suffix",
  );

  var data = elements[0].attributes['items-json'];
  if (data == null || data.isEmpty) {
    throw Exception("Missing items-json attribute");
  }
  var json = jsonDecode(data);
  return json['data'];
}

Future<Map<String, dynamic>> fetchTopAnimePage({
  String? status,
  String? type,
  String? order,
  bool popular = false,
  int page = 1,
}) async {
  final params = <String, String>{};
  if (status != null && status.isNotEmpty) {
    params['status'] = status;
  }
  if (type != null && type.isNotEmpty) {
    params['type'] = type;
  }
  if (order != null && order.isNotEmpty) {
    params['order'] = order;
  }
  if (popular) {
    params['popular'] = 'true';
  }
  if (page > 1) {
    params['page'] = page.toString();
  }

  final uri = Uri.parse("$_baseHost/top-anime").replace(
    queryParameters: params.isEmpty ? null : params,
  );

  List<Element> elements = await getElements(
    'top-anime',
    url: uri.toString(),
  );

  var data = elements[0].attributes['animes'];
  if (data == null || data.isEmpty) {
    throw Exception("Missing animes attribute");
  }
  var json = jsonDecode(data);
  if (json is! Map) {
    throw Exception("Invalid top-anime payload");
  }

  return {
    'data': json['data'] ?? [],
    'current_page': json['current_page'] ?? page,
    'last_page': json['last_page'] ?? page,
  };
}

Future<List> fetchTopAnime({
  String? status,
  String? type,
  String? order,
  bool popular = false,
}) async {
  final page = await fetchTopAnimePage(
    status: status,
    type: type,
    order: order,
    popular: popular,
  );
  return page['data'] ?? [];
}

Future<List<Map<String, dynamic>>> fetchCalendarioItems() async {
  final document = await makeRequestAndGetDocument("$_baseHost/calendario");
  final elements = document.getElementsByTagName('calendario-item');
  if (elements.isEmpty) {
    throw Exception("No calendario-item elements found");
  }

  final items = <Map<String, dynamic>>[];
  for (final element in elements) {
    final raw = element.attributes['a'];
    if (raw == null || raw.isEmpty) {
      continue;
    }
    final decoded = _decodeHtmlAttribute(raw);
    final data = jsonDecode(decoded);
    if (data is Map) {
      items.add(data.cast<String, dynamic>());
    }
  }

  return items;
}

Future<List> searchAnime({String title = ""}) async {
  final normalizedTitle = title.trim();
  final session = await _getAnimeunitySession();
  final headers = _buildSessionHeaders(session);

  final results = <dynamic>[];
  final ids = <int>{};

  if (normalizedTitle.isNotEmpty) {
    try {
      final response = await http.post(
        Uri.parse("$_baseHost/livesearch"),
        headers: {
          ...headers,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "title": normalizedTitle,
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is Map && payload["records"] is List) {
          for (final record in payload["records"]) {
            if (record is Map && record["id"] is int) {
              if (ids.add(record["id"])) {
                results.add(record);
              }
            }
          }
        }
      }
    } catch (_) {
      // Ignore to try the second search endpoint.
    }
  }

  try {
    final payload = {
      "title": normalizedTitle,
      "type": false,
      "year": false,
      "order": false,
      "status": false,
      "genres": false,
      "offset": 0,
      "dubbed": false,
      "season": false,
    };

    final response = await http.post(
      Uri.parse("$_baseHost/archivio/get-animes"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload["records"] is List) {
        for (final record in payload["records"]) {
          if (record is Map && record["id"] is int) {
            if (ids.add(record["id"])) {
              results.add(record);
            }
          }
        }
      }
    }
  } catch (_) {
    // ignore
  }

  return results;
}

Future<List> fetchAnimeEpisodes(int animeId) async {
  final headers = {
    ..._defaultHeaders,
    "Referer": "$_baseHost/",
  };

  final infoResponse = await http.get(
    Uri.parse("$_baseHost/info_api/$animeId/"),
    headers: headers,
  );
  if (infoResponse.statusCode < 200 || infoResponse.statusCode >= 300) {
    throw Exception("HTTP ${infoResponse.statusCode} for info_api");
  }

  final info = jsonDecode(infoResponse.body);
  final totalCount = info is Map ? (info["episodes_count"] ?? 0) : 0;
  if (totalCount == 0) {
    return [];
  }

  final List episodes = [];
  int start = 1;
  while (start <= totalCount) {
    final end = (start + 119) <= totalCount ? (start + 119) : totalCount;
    final url = Uri.parse("$_baseHost/info_api/$animeId/1")
        .replace(queryParameters: {
      "start_range": start.toString(),
      "end_range": end.toString(),
    });

    final response = await http.get(url, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("HTTP ${response.statusCode} for info_api range");
    }
    final data = jsonDecode(response.body);
    if (data is Map && data["episodes"] is List) {
      episodes.addAll(data["episodes"]);
    }
    start = end + 1;
  }

  return episodes;
}

Future<Map<String, dynamic>> fetchAnimeEpisodesRange({
  required int animeId,
  required int startRange,
  required int endRange,
  int? totalCountHint,
}) async {
  final headers = {
    ..._defaultHeaders,
    "Referer": "$_baseHost/",
  };

  int totalCount = totalCountHint ?? 0;
  if (totalCount <= 0) {
    final infoResponse = await http.get(
      Uri.parse("$_baseHost/info_api/$animeId/"),
      headers: headers,
    );
    if (infoResponse.statusCode < 200 || infoResponse.statusCode >= 300) {
      throw Exception("HTTP ${infoResponse.statusCode} for info_api");
    }
    final info = jsonDecode(infoResponse.body);
    totalCount = info is Map ? (info["episodes_count"] ?? 0) : 0;
  }

  if (totalCount <= 0) {
    return {
      'episodes': <dynamic>[],
      'totalCount': 0,
    };
  }

  final safeStart = startRange.clamp(1, totalCount);
  final safeEnd = endRange.clamp(safeStart, totalCount);

  final url = Uri.parse("$_baseHost/info_api/$animeId/1").replace(
    queryParameters: {
      "start_range": safeStart.toString(),
      "end_range": safeEnd.toString(),
    },
  );

  final response = await http.get(url, headers: headers);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception("HTTP ${response.statusCode} for info_api range");
  }
  final data = jsonDecode(response.body);
  final List episodes =
      data is Map && data["episodes"] is List ? data["episodes"] : [];

  return {
    'episodes': episodes,
    'totalCount': totalCount,
  };
}

String? _extractDownloadUrl(String html) {
  final match = RegExp(r"window\.downloadUrl\s*=\s*'([^']+)'").firstMatch(html);
  if (match != null) {
    return match.group(1);
  }
  final alt = RegExp("(https?://[^\\s'\"<>]+(?:mp4|m3u8)[^\\s'\"<>]*)")
      .firstMatch(html);
  return alt?.group(1);
}

Future<String> fetchEpisodeStreamUrl(int episodeId) async {
  final headers = {
    ..._defaultHeaders,
    "Referer": "$_baseHost/",
  };

  final embedResponse = await http.get(
    Uri.parse("$_baseHost/embed-url/$episodeId"),
    headers: headers,
  );

  if (embedResponse.statusCode < 200 || embedResponse.statusCode >= 300) {
    throw Exception("HTTP ${embedResponse.statusCode} for embed-url");
  }

  final embedUrl = (embedResponse.headers["location"] ?? embedResponse.body).trim();
  if (!embedUrl.startsWith("http")) {
    throw Exception("Invalid embed url");
  }

  final pageResponse = await http.get(
    Uri.parse(embedUrl),
    headers: {
      ...headers,
      "Referer": "$_baseHost/embed-url/$episodeId",
    },
  );

  if (pageResponse.statusCode < 200 || pageResponse.statusCode >= 300) {
    throw Exception("HTTP ${pageResponse.statusCode} for embed page");
  }

  final url = _extractDownloadUrl(pageResponse.body);
  if (url == null || url.isEmpty) {
    throw Exception("No stream url found");
  }

  return url;
}

Future<List> toContinueAnime() {
  List<AnimeModel> animes = objBox.getAll() as List<AnimeModel>;
  animes.sort((a, b) {
    if (a.lastSeenDate == null) {
      return 1;
    } else if (b.lastSeenDate == null) {
      return -1;
    } else {
      return a.lastSeenDate!.millisecondsSinceEpoch > b.lastSeenDate!.millisecondsSinceEpoch ? -1 : 1;
    }
  });

  return Future.value(animes);
}

AnimeModel fetchAnimeModel(AnimeClass anime) {
  AnimeModel? tmp = objBox.get(anime.id);
  AnimeModel toPut = anime.toModel;

  if (tmp != null) {
    toPut = tmp;
  }

  toPut.decodeStr();

  return toPut;
}

String getLatestAndroidApkUrl(String tag) {
  return "${internalAPI.repoLink}/releases/download/$tag/app-release.apk";
}

String getLatestIosIpaUrl(String tag) {
  return "${internalAPI.repoLink}/releases/download/$tag/AniVerse-unsigned.ipa";
}

String normalizeVersion(String version) {
  var result = version.trim();
  if (result.startsWith("v") || result.startsWith("V")) {
    result = result.substring(1);
  }
  final plusIndex = result.indexOf("+");
  if (plusIndex != -1) {
    result = result.substring(0, plusIndex);
  }
  return result;
}

Future<String> getLatestReleaseTag() async {
  var url = Uri.parse(
    "${internalAPI.repoLink}/releases/latest",
  );

  try {
    var response = await http.get(url);
    var document = parse(response.body);

    var release = document.getElementsByTagName('h1').firstWhere((element) => element.text.startsWith("Release"));

    var tag = release.text.replaceAll("Release ", "").trim();
    return tag;
  } catch (e) {
    return "";
  }
}

void eraseDb() {
  objBox.removeAll();
}

Future<String> getPublicIpAddress() async {
  var url = Uri.parse("https://ifconfig.io/ip");
  try {
    var response = await http.get(url);
    return response.body.replaceAll("\n", "");
  } catch (e) {
    return "";
  }
}

