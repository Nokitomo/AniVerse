import 'dart:io';

import 'package:aniverse/helper/api.dart';
import 'package:aniverse/services/internal_api.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class UpdateApp extends StatelessWidget {
  UpdateApp({super.key});

  final InternalAPI internalAPI = Get.find<InternalAPI>();

  beginUpdate(tag) async {
    var url = getLatestAndroidApkUrl(tag);
    var progress = 0.obs;

    try {
      OtaUpdate().execute(url).listen((OtaEvent event) {
        progress.value = int.tryParse(event.value!) ?? progress.value;
      });
      Get.dialog(
        AlertDialog(
          title: const Text("Download"),
          content: Row(
            children: [
              const Text("Sto scaricando l'aggiornamento... :D"),
              const SizedBox(width: 10),
              SizedBox(
                height: 20,
                width: 20,
                child: Obx(
                  () => CircularProgressIndicator(
                    value: progress.value / 100,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Errore durante l'aggiornamento");
    }
  }

  Future<File> _downloadFile(
    String url,
    String filename,
    RxInt progress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File(path.join(dir.path, filename));
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close();
      throw Exception("HTTP ${response.statusCode}");
    }

    final totalBytes = response.contentLength ?? 0;
    if (totalBytes > 0) {
      progress.value = 0;
    }

    final sink = file.openWrite();
    var receivedBytes = 0;
    var sinkClosed = false;
    Future<void> closeSink() async {
      if (!sinkClosed) {
        sinkClosed = true;
        await sink.close();
      }
    }

    try {
      await response.stream.listen((chunk) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        if (totalBytes > 0) {
          final pct = ((receivedBytes / totalBytes) * 100)
              .clamp(0, 100)
              .round();
          if (pct != progress.value) {
            progress.value = pct;
          }
        }
      }).asFuture();
      await closeSink();
      client.close();
      return file;
    } catch (_) {
      await closeSink();
      client.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<void> _shareAndMaybeDelete(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Aggiornamento AniVerse",
    );

    final shouldDelete = await Get.dialog<bool>(
          AlertDialog(
            title: const Text("Pulizia file"),
            content: const Text(
              "Vuoi eliminare il file IPA scaricato?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(result: false);
                },
                child: const Text("Tieni"),
              ),
              TextButton(
                onPressed: () {
                  Get.back(result: true);
                },
                child: const Text("Elimina"),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldDelete) {
      try {
        await file.delete();
      } catch (_) {
        Fluttertoast.showToast(
          msg: "Non riesco a eliminare il file scaricato.",
        );
      }
    }
  }

  beginIosUpdate(tag) async {
    final url = getLatestIosIpaUrl(tag);
    final progress = (-1).obs;

    Get.dialog(
      AlertDialog(
        title: const Text("Download"),
        content: Row(
          children: [
            const Text("Sto scaricando l'aggiornamento..."),
            const SizedBox(width: 10),
            SizedBox(
              height: 20,
              width: 20,
              child: Obx(
                () => CircularProgressIndicator(
                  value: progress.value < 0 ? null : progress.value / 100,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final file = await _downloadFile(
        url,
        "AniVerse-$tag.ipa",
        progress,
      );
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      await _shareAndMaybeDelete(file);
    } catch (_) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Fluttertoast.showToast(
        msg: "Errore durante il download dell'aggiornamento",
      );
    }
  }

  checkUpdate() async {
    Fluttertoast.showToast(msg: "Controllo aggiornamenti...");

    String latestTag = await getLatestReleaseTag();
    String current = await internalAPI.getVersion();
    String latest = normalizeVersion(latestTag);
    String normalizedCurrent = normalizeVersion(current);

    if (latestTag.isEmpty || latest.isEmpty) {
      Fluttertoast.showToast(
        msg: "Errore durante il controllo degli aggiornamenti",
      );
      return;
    }

    if (latest == normalizedCurrent) {
      Fluttertoast.showToast(msg: "L'app e' gia' aggiornata :D");
    } else {
      if (Platform.isAndroid) {
        Get.dialog(
          AlertDialog(
            title: const Text("Aggiornamento disponibile"),
            content: const Text(
              "E' disponibile un aggiornamento per l'app, vuoi aggiornare?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                },
                child: const Text("Annulla"),
              ),
              TextButton(
                onPressed: () async {
                  Get.back();
                  Fluttertoast.showToast(msg: "Download in corso...");
                  await beginUpdate(latestTag);
                },
                child: const Text("Aggiorna"),
              ),
            ],
          ),
        );
      } else {
        Get.dialog(
          AlertDialog(
            title: const Text("Aggiornamento disponibile"),
            content: const Text(
              "Su iOS l'aggiornamento viene scaricato come file IPA. Dopo il download, aprilo con LiveContainer per installare la nuova versione.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                },
                child: const Text("Annulla"),
              ),
              TextButton(
                onPressed: () async {
                  Get.back();
                  Fluttertoast.showToast(msg: "Download in corso...");
                  await beginIosUpdate(latestTag);
                },
                child: const Text("Scarica e apri"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        "Aggiorna l'app",
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontSize: 16,
          fontFamily: "Roboto",
        ),
      ),
      subtitle: Text(
        "Aggiorna l'app all'ultima versione disponibile",
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontSize: 13,
          fontFamily: "Roboto",
        ),
      ),
      trailing: ElevatedButton(
        onPressed: () {
          checkUpdate();
        },
        child: const Text(
          "Aggiorna",
          style: TextStyle(
            fontFamily: "Roboto",
          ),
        ),
      ),
    );
  }
}
