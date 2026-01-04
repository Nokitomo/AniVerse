import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScWebViewClient {
  WebViewController? _controller;
  Future<void> _queue = Future.value();

  void attachController(WebViewController controller) {
    _controller = controller;
  }

  Future<String> fetchDataPageAttribute(String url) {
    return _enqueue(() async {
      final controller = _controller;
      if (controller == null) {
        throw Exception('StreamingCommunity WebView non pronta');
      }

      final completer = Completer<void>();
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onWebResourceError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        ),
      );

      await controller.loadRequest(Uri.parse(url));
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Timeout WebView per $url'),
      );

      final result = await controller.runJavaScriptReturningResult(
        "document.querySelector('#app')?.getAttribute('data-page')",
      );

      final normalized = _normalizeJsResult(result);
      if (normalized.trim().isEmpty) {
        throw Exception('data-page vuoto per $url');
      }
      return normalized;
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
}
