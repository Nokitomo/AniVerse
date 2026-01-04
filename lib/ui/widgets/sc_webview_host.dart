import 'package:aniverse/services/sc_webview_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScWebViewHost extends StatefulWidget {
  const ScWebViewHost({super.key});

  @override
  State<ScWebViewHost> createState() => _ScWebViewHostState();
}

class _ScWebViewHostState extends State<ScWebViewHost> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
      )
      ..loadHtmlString('<html><body></body></html>');

    Get.find<ScWebViewClient>().attachHiddenController(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Opacity(
        opacity: 0.0,
        child: SizedBox(
          width: 1,
          height: 1,
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
