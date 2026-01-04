import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/ui/widgets/sc_media_row.dart';
import 'package:flutter/material.dart';

class ScExplorePage extends StatefulWidget {
  const ScExplorePage({super.key});

  @override
  State<ScExplorePage> createState() => _ScExplorePageState();
}

class _ScExplorePageState extends State<ScExplorePage> {
  Future<ScHomePayload> _loadBasePayload() {
    return fetchStreamingCommunityHome();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: FutureBuilder<ScHomePayload>(
          future: _loadBasePayload(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Impossibile caricare StreamingCommunity",
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
            final rows = [
              ScMediaRow(
                loader: () async {
                  final slider = await fetchStreamingCommunitySlider('trending');
                  return slider.titles;
                },
                title: 'Trending',
                cdnUrl: cdnUrl,
                itemLimit: 30,
              ),
              ScMediaRow(
                loader: () async {
                  final slider = await fetchStreamingCommunitySlider('latest');
                  return slider.titles;
                },
                title: 'Nuovi arrivi',
                cdnUrl: cdnUrl,
                itemLimit: 30,
              ),
              ScMediaRow(
                loader: () async {
                  final slider = await fetchStreamingCommunitySlider('top10');
                  return slider.titles;
                },
                title: 'Top 10',
                cdnUrl: cdnUrl,
                itemLimit: 10,
              ),
              ScMediaRow(
                loader: () async {
                  return fetchStreamingCommunityArchive();
                },
                title: 'Archivio',
                cdnUrl: cdnUrl,
                itemLimit: 30,
              ),
            ];
            return Padding(
              padding: const EdgeInsets.all(10.0),
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView.separated(
                  itemBuilder: (context, index) => rows[index],
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemCount: rows.length,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
