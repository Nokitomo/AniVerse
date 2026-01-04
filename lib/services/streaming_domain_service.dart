import 'dart:convert';

import 'package:aniverse/services/internal_api.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

const String _domainsUrl =
    'https://raw.githubusercontent.com/Arrowar/SC_Domains/refs/heads/main/domains.json';
const Duration _domainsCacheDuration = Duration(hours: 12);

final InternalAPI _internalApi = Get.find<InternalAPI>();

const Map<String, String> _defaultHeaders = {
  'Accept': 'application/json',
  'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
};

String _normalizeBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
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
  final cachedRaw = _internalApi.getKeyValue('sc_domains_cache');
  final cachedAtRaw = _internalApi.getKeyValue('sc_domains_cache_time');
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
        _internalApi.setKeyValue('sc_domains_cache', jsonEncode(domains));
        _internalApi.setKeyValue('sc_domains_cache_time', now.toIso8601String());
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

Future<String> getStreamingUnityBaseUrl() async {
  return 'https://streamingunity.so';
}
