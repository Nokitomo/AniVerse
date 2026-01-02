import 'dart:async';
import 'dart:io';

import 'package:aniverse/helper/api.dart';
import 'package:aniverse/services/internal_api.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as p_provider;
import 'package:url_launcher/url_launcher.dart';

class DesktopUpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final bool available;

  const DesktopUpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.available,
  });
}

class DesktopUpdateService {
  DesktopUpdateService({required this.internalApi});

  final InternalAPI internalApi;
  Timer? _timer;
  bool _checking = false;

  String get _windowsAppInstallerUrl =>
      '${internalApi.repoLink}/releases/latest/download/AniVerse.appinstaller';

  String get _linuxAppImageUrl =>
      '${internalApi.repoLink}/releases/latest/download/AniVerse-x86_64.AppImage';

  Future<void> startBackgroundChecks({
    Duration interval = const Duration(hours: 6),
  }) async {
    if (!(Platform.isWindows || Platform.isLinux)) {
      return;
    }
    await _checkAndNotify();
    _timer = Timer.periodic(interval, (_) {
      _checkAndNotify();
    });
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<DesktopUpdateInfo?> checkForUpdates() async {
    if (Platform.isWindows) {
      return _checkWindowsUpdate();
    }
    if (Platform.isLinux) {
      return _checkLinuxUpdate();
    }
    return null;
  }

  Future<void> applyUpdate(DesktopUpdateInfo info) async {
    if (!info.available) {
      return;
    }
    if (Platform.isWindows) {
      await _launchWindowsInstaller();
      return;
    }
    if (Platform.isLinux) {
      await _applyLinuxUpdate(info);
    }
  }

  Future<void> _checkAndNotify() async {
    if (_checking) {
      return;
    }
    _checking = true;
    try {
      final info = await checkForUpdates();
      if (info != null && info.available) {
        Fluttertoast.showToast(
          msg: "Aggiornamento desktop disponibile",
        );
      }
    } finally {
      _checking = false;
    }
  }

  Future<DesktopUpdateInfo?> _checkWindowsUpdate() async {
    try {
      final response = await http.get(Uri.parse(_windowsAppInstallerUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final latest = _extractAppInstallerVersion(response.body);
      if (latest == null) {
        return null;
      }
      final current = await _getCurrentVersion();
      final available = _compareVersions(latest, current) > 0;
      return DesktopUpdateInfo(
        latestVersion: latest,
        downloadUrl: _windowsAppInstallerUrl,
        available: available,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DesktopUpdateInfo?> _checkLinuxUpdate() async {
    try {
      final latestTag = await getLatestReleaseTag();
      final latest = normalizeVersion(latestTag);
      if (latest.isEmpty) {
        return null;
      }
      final current = await _getCurrentVersion();
      final available = _compareVersions(latest, current) > 0;
      return DesktopUpdateInfo(
        latestVersion: latest,
        downloadUrl: _linuxAppImageUrl,
        available: available,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _launchWindowsInstaller() async {
    final uri = Uri.parse(
      'ms-appinstaller:?source=${Uri.encodeComponent(_windowsAppInstallerUrl)}',
    );
    if (!await canLaunchUrl(uri)) {
      Fluttertoast.showToast(
        msg: "Impossibile aprire App Installer",
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _applyLinuxUpdate(DesktopUpdateInfo info) async {
    final appImagePath = Platform.environment['APPIMAGE'];
    if (appImagePath == null || appImagePath.isEmpty) {
      Fluttertoast.showToast(
        msg: "Aggiornamento disponibile solo da AppImage",
      );
      return;
    }

    final tempDir = await p_provider.getTemporaryDirectory();
    final targetPath =
        p.join(tempDir.path, 'AniVerse-${info.latestVersion}.AppImage');
    await _downloadFile(info.downloadUrl, targetPath);

    final scriptPath = p.join(tempDir.path, 'aniverse-update.sh');
    final script = StringBuffer()
      ..writeln('#!/bin/sh')
      ..writeln('set -e')
      ..writeln('PID=${pid}')
      ..writeln('APPIMAGE="${_escapeShell(appImagePath)}"')
      ..writeln('NEW_IMAGE="${_escapeShell(targetPath)}"')
      ..writeln('while kill -0 $PID 2>/dev/null; do sleep 1; done')
      ..writeln('mv "$NEW_IMAGE" "$APPIMAGE"')
      ..writeln('chmod +x "$APPIMAGE"');
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString(script.toString());
    await Process.run('chmod', ['+x', scriptPath]);

    await Process.start(
      'sh',
      [scriptPath],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  Future<void> _downloadFile(String url, String path) async {
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("HTTP ${response.statusCode}");
      }
      final file = File(path);
      final sink = file.openWrite();
      await response.stream.pipe(sink);
    } finally {
      client.close();
    }
  }

  Future<String> _getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return normalizeVersion(info.version);
  }

  String? _extractAppInstallerVersion(String xml) {
    final match =
        RegExp(r'MainPackage[^>]*Version="([^"]+)"').firstMatch(xml);
    return match?.group(1);
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;
    while (aParts.length < maxLen) {
      aParts.add(0);
    }
    while (bParts.length < maxLen) {
      bParts.add(0);
    }
    for (var i = 0; i < maxLen; i++) {
      if (aParts[i] != bParts[i]) {
        return aParts[i].compareTo(bParts[i]);
      }
    }
    return 0;
  }

  String _escapeShell(String input) {
    return input.replaceAll('"', '\\"');
  }
}
