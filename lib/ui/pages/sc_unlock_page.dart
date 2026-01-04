import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/services/sc_webview_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScUnlockPage extends StatefulWidget {
  const ScUnlockPage({super.key});

  @override
  State<ScUnlockPage> createState() => _ScUnlockPageState();
}

class _ScUnlockPageState extends State<ScUnlockPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
              });
            }
          },
        ),
      );

    Get.find<ScWebViewClient>().attachVisibleController(_controller);
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final baseUrl = await getStreamingCommunityBaseUrl();
      await _controller.loadRequest(Uri.parse('$baseUrl/'));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Impossibile aprire StreamingCommunity';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    Get.find<ScWebViewClient>().detachVisibleController(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sblocca StreamingCommunity'),
        actions: [
          IconButton(
            onPressed: _loadBaseUrl,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Completa eventuali richieste di Cloudflare. '
              'Quando la pagina si apre correttamente, torna indietro.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ho sbloccato'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
