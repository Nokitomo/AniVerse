import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/ui/pages/sc_title_detail_page.dart';
import 'package:aniverse/ui/widgets/sc_media_row.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ScHomePage extends StatefulWidget {
  const ScHomePage({super.key});

  @override
  State<ScHomePage> createState() => _ScHomePageState();
}

class _ScHomePageState extends State<ScHomePage> {
  Future<ScHomePayload> _loadHomePayload() {
    return fetchStreamingCommunityHome();
  }

  String _resolveBannerUrl(ScSlideBanner banner, String cdnUrl) {
    final value = banner.imageUrl.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('http')) {
      return value;
    }
    if (cdnUrl.trim().isEmpty) {
      return value;
    }
    return '${cdnUrl.trim()}/$value';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: FutureBuilder<ScHomePayload>(
          future: _loadHomePayload(),
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
            final payload = snapshot.data!;
            final cdnUrl = payload.cdnUrl;
            final banner = payload.slideBanners.isNotEmpty
                ? payload.slideBanners.first
                : null;
            final bannerUrl =
                banner != null ? _resolveBannerUrl(banner, cdnUrl) : '';

            final rows = [
              if (bannerUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.background,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.background,
                        child: const Center(
                          child: Icon(Icons.warning_amber_rounded, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ScMediaRow(
                loader: () async {
                  final slider = await fetchStreamingCommunitySlider('trending');
                  return slider.titles;
                },
                title: 'Trending',
                cdnUrl: cdnUrl,
                onItemTap: (media) => Get.to(
                  () => ScTitleDetailPage(media: media),
                ),
              ),
              ScMediaRow(
                loader: () async {
                  final slider = await fetchStreamingCommunitySlider('latest');
                  return slider.titles;
                },
                title: 'Aggiunti di recente',
                cdnUrl: cdnUrl,
                onItemTap: (media) => Get.to(
                  () => ScTitleDetailPage(media: media),
                ),
              ),
              ScMediaRow(
                loader: () async {
                  final slider = await fetchStreamingCommunitySlider('top10');
                  return slider.titles;
                },
                title: 'Top 10',
                cdnUrl: cdnUrl,
                itemLimit: 10,
                onItemTap: (media) => Get.to(
                  () => ScTitleDetailPage(media: media),
                ),
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
