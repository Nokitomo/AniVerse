import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScWebViewClient {
  WebViewController? _controller;
  Future<void> _queue = Future.value();
  Completer<void>? _pageLoadCompleter;

  void attachController(WebViewController controller) {
    _controller = controller;
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) {
          final completer = _pageLoadCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        },
        onWebResourceError: (error) {
          final completer = _pageLoadCompleter;
          final isMainFrame = error.isForMainFrame == true;
          if (isMainFrame) {
            debugPrint(
              'SC WebView error mainFrame url=${error.url} '
              'code=${error.errorCode} desc=${error.description}',
            );
          }
          if (isMainFrame && completer != null && !completer.isCompleted) {
            completer.completeError(error);
          }
        },
      ),
    );
  }

  Future<String> fetchDataPageAttribute(String url) {
    return _enqueue(() async {
      final controller = _controller;
      if (controller == null) {
        throw Exception('StreamingCommunity WebView non pronta');
      }

      _pageLoadCompleter = Completer<void>();
      await controller.loadRequest(Uri.parse(url));
      await _pageLoadCompleter!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Timeout WebView per $url'),
      );

      final dataPage = await _readDataPageWithRetry(controller);
      if (dataPage.trim().isEmpty) {
        throw Exception('data-page vuoto per $url');
      }
      return dataPage;
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  String _normalizeJsResult(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
        return '';
      }
      if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          trimmed.contains(r'\u')) {
        try {
          return jsonDecode(trimmed).toString();
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    return value.toString();
  }

  Future<String> _readDataPageWithRetry(WebViewController controller) async {
    const attempts = 8;
    const delay = Duration(milliseconds: 400);
    for (var i = 0; i < attempts; i++) {
      final result = await controller.runJavaScriptReturningResult(
        "document.querySelector('#app')?.getAttribute('data-page') || ''",
      );
      final normalized = _normalizeJsResult(result);
      if (normalized.trim().isNotEmpty) {
        return normalized;
      }
      await Future.delayed(delay);
    }
    return '';
  }
}
