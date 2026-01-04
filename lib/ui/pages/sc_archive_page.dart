import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/ui/pages/sc_title_detail_page.dart';
import 'package:aniverse/ui/widgets/sc_media_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ScArchivePage extends StatefulWidget {
  const ScArchivePage({super.key});

  @override
  State<ScArchivePage> createState() => _ScArchivePageState();
}

class _ScArchivePageState extends State<ScArchivePage> {
  Future<ScHomePayload> _loadPayload() {
    return fetchStreamingCommunityHome();
  }

  Future<List<ScMedia>> _loadArchive() {
    return fetchStreamingCommunityArchive();
  }

  void _openDetail(ScMedia media) {
    Get.to(() => ScTitleDetailPage(media: media));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: FutureBuilder<ScHomePayload>(
          future: _loadPayload(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Impossibile caricare l'archivio",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 18,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cdnUrl = snapshot.data!.cdnUrl;
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: FutureBuilder<List<ScMedia>>(
                future: _loadArchive(),
                builder: (context, archiveSnapshot) {
                  if (archiveSnapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            "Errore nel caricamento dell'archivio",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  if (!archiveSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = archiveSnapshot.data ?? [];
                  if (items.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            "Nessun contenuto disponibile",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final media = items[index];
                      return ScMediaCard(
                        media: media,
                        cdnUrl: cdnUrl,
                        onTap: () => _openDetail(media),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
