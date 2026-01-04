import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/services/app_section_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScWebViewPage extends StatefulWidget {
  const ScWebViewPage({super.key});

  @override
  State<ScWebViewPage> createState() => _ScWebViewPageState();
}

class _ScWebViewPageState extends State<ScWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _homeUrl;
  String? _baseHost;

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
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: (_) => _syncState(),
        ),
      );
    _loadHome();
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (!request.isMainFrame) {
      return NavigationDecision.navigate;
    }
    final uri = Uri.tryParse(request.url);
    if (uri == null) {
      return NavigationDecision.prevent;
    }
    if (uri.scheme == 'about' ||
        uri.scheme == 'data' ||
        uri.scheme == 'blob') {
      return NavigationDecision.navigate;
    }
    final host = uri.host.toLowerCase();
    if (_isAnimeUnityHost(host)) {
      Get.find<AppSectionController>().switchTo(AppSection.anime);
      return NavigationDecision.prevent;
    }
    if (_isAllowedHost(host)) {
      return NavigationDecision.navigate;
    }
    return NavigationDecision.prevent;
  }

  Future<void> _syncState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
    });
    final baseUrl = await getStreamingCommunityBaseUrl();
    _homeUrl = '$baseUrl/';
    _baseHost = Uri.parse(baseUrl).host.toLowerCase();
    await _controller.loadRequest(Uri.parse(_homeUrl!));
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
    });
    await _controller.reload();
  }

  Future<void> _goHome() async {
    if (_homeUrl == null) {
      await _loadHome();
      return;
    }
    setState(() {
      _loading = true;
    });
    await _controller.loadRequest(Uri.parse(_homeUrl!));
  }

  bool _isAllowedHost(String host) {
    final baseHost = _baseHost;
    if (baseHost != null && _isSameOrSubdomain(host, baseHost)) {
      return true;
    }
    if (_isSameOrSubdomain(host, 'vixcloud.co')) {
      return true;
    }
    if (_isSameOrSubdomain(host, 'scws-content.net')) {
      return true;
    }
    return false;
  }

  bool _isAnimeUnityHost(String host) {
    return _isSameOrSubdomain(host, 'animeunity.so');
  }

  bool _isSameOrSubdomain(String host, String allowedHost) {
    return host == allowedHost || host.endsWith('.$allowedHost');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Indietro',
                onPressed: _canGoBack
                    ? () async {
                        await _controller.goBack();
                        await _syncState();
                      }
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: 'Avanti',
                onPressed: _canGoForward
                    ? () async {
                        await _controller.goForward();
                        await _syncState();
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: 'Home',
                onPressed: _goHome,
                icon: const Icon(Icons.home),
              ),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
              const Spacer(),
              if (_loading) const SizedBox.square(dimension: 20, child: CircularProgressIndicator()),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}
