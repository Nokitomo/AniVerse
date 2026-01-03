import 'dart:io';
import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:aniverse/services/internal_db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as p_provider;

class InternalAPI {
  late SharedPreferences prefs;
  ObjectBox objBox = Get.find<ObjectBox>();

  late final String dbPath;
  late final String dbBackupPath;

  final String repoLink = "https://github.com/Nokitomo/AniVerse";

  Future<Directory> _getBaseDirectory() async {
    if (Platform.isAndroid) {
      return p_provider.getApplicationDocumentsDirectory();
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return p_provider.getLibraryDirectory();
    }
    return p_provider.getApplicationSupportDirectory();
  }

  Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();

    final docsDir = await _getBaseDirectory();

    dbPath = p.join(docsDir.path, "obx");
    dbBackupPath = p.join(docsDir.path, "obx-backup");
  }

  String getFakeServer() {
    return prefs.getString('fakeServer') ?? '';
  }

  Future<void> setFakeServer(String value) async {
    await prefs.setString('fakeServer', value);
  }

  bool getDarkThemeStatus() {
    return prefs.getBool('darkTheme') ?? ThemeMode.system == ThemeMode.dark;
  }

  bool getDynamicThemeStatus() {
    return prefs.getBool('dynamicTheme') ?? false;
  }

  Future<void> setDarkThemeStatus(bool value) async {
    await prefs.setBool('darkTheme', value);
  }

  Future<void> setDynamicThemeStatus(bool value) async {
    await prefs.setBool('dynamicTheme', value);
  }

  Future<String> getVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return info.version;
  }

  void setWaitTime(int parse) {
    prefs.setInt('waitTime', parse);
  }

  int getWaitTime() {
    return prefs.getInt('waitTime') ?? 2;
  }

  void setKeyValue(String key, String value) {
    prefs.setString(key, value);
  }

  String getKeyValue(String key) {
    return prefs.getString(key) ?? '';
  }

  static const String _bannerCacheKey = 'bannerCache';
  static const String _homeCarouselCacheKey = 'homeCarouselCache';
  static const String _homeCarouselCacheWeekKey = 'homeCarouselCacheWeek';

  Map<String, String> getBannerCache() {
    final raw = prefs.getString(_bannerCacheKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(
              key.toString(),
              value?.toString() ?? '',
            ));
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> setBannerCache({
    required Map<String, String> cache,
  }) async {
    await prefs.setString(_bannerCacheKey, jsonEncode(cache));
  }

  List<Map<String, dynamic>> getHomeCarouselCache() {
    final raw = prefs.getString(_homeCarouselCacheKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((item) {
          return item.cast<String, dynamic>();
        }).toList();
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  String getHomeCarouselCacheWeekKey() {
    return prefs.getString(_homeCarouselCacheWeekKey) ?? '';
  }

  Future<void> setHomeCarouselCache({
    required List<Map<String, dynamic>> items,
    required String weekKey,
  }) async {
    await prefs.setString(_homeCarouselCacheKey, jsonEncode(items));
    await prefs.setString(_homeCarouselCacheWeekKey, weekKey);
  }

  Future<int> exportDb() async {
    String path = "/sdcard/Documents/obx.zip";
    if (!Platform.isAndroid) {
      Directory? dir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        dir = await p_provider.getDownloadsDirectory();
      }
      dir ??= await p_provider.getApplicationDocumentsDirectory();
      path = p.join(dir.path, "obx.zip");
    }

    try {
      var encoder = ZipFileEncoder();
      encoder.zipDirectory(
        Directory(dbPath),
        filename: path,
      );
      return 0;
    } catch (e) {
      if (kDebugMode) rethrow;
      return 1;
    }
  }

  importDb(String backupPath) async {
    try {
      var bytes = File(backupPath).readAsBytesSync();
      var archive = ZipDecoder().decodeBytes(bytes);

      for (var file in archive) {
        var filename = file.name;
        var data = file.content as List<int>;

        File(p.join(dbPath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }

      return 0;
    } catch (e) {
      if (kDebugMode) rethrow;
      return 1;
    }
  }
}

