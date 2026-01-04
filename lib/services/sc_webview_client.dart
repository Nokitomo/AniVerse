import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScWebViewClient {
  WebViewController? _controller;
  Future<void> _queue = Future.value();
  Completer<void>? _pageLoadCompleter;
  String? _currentOrigin;

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

      await _loadUrlAndWait(controller, url);
      _currentOrigin = Uri.parse(url).origin;

      final dataPage = await _readDataPageWithRetry(controller);
      if (dataPage.trim().isNotEmpty) {
        return dataPage;
      }

      final htmlResult = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final html = _normalizeJsResult(htmlResult);
      if (html.trim().isEmpty) {
        throw Exception('data-page vuoto per $url');
      }
      return html;
    });
  }

  Future<ScWebViewResponse> fetchText({
    required String url,
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) {
    return _enqueue(() async {
      final controller = _controller;
      if (controller == null) {
        throw Exception('StreamingCommunity WebView non pronta');
      }

      final origin = Uri.parse(url).origin;
      if (_currentOrigin != origin) {
        await _loadUrlAndWait(controller, '$origin/');
        _currentOrigin = origin;
      }

      final payload = <String, dynamic>{
        'method': method,
        'headers': headers ?? const <String, String>{},
        if (body != null) 'body': body,
      };
      final jsPayload = jsonEncode(payload);
      final js = '''
        (async () => {
          try {
            const opts = $jsPayload;
            const method = opts.method || 'GET';
            const headers = opts.headers || {};
            const init = { method, headers, credentials: 'include' };
            if (opts.body !== undefined && opts.body !== null) {
              if (typeof opts.body === 'string') {
                init.body = opts.body;
              } else {
                init.body = JSON.stringify(opts.body);
                if (!headers['Content-Type'] && !headers['content-type']) {
                  headers['Content-Type'] = 'application/json';
                }
              }
            }
            const resp = await fetch('${_escapeJsString(url)}', init);
            const text = await resp.text();
            return JSON.stringify({ status: resp.status, body: text });
          } catch (err) {
            return JSON.stringify({ status: 0, body: '', error: String(err) });
          }
        })();
      ''';
      final result = await controller.runJavaScriptReturningResult(js);
      final normalized = _normalizeJsResult(result);
      if (normalized.trim().isEmpty) {
        throw Exception('Risposta WebView vuota per $url');
      }
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        throw Exception('Risposta WebView non valida per $url');
      }
      final status = decoded['status'];
      return ScWebViewResponse(
        status is int ? status : int.tryParse('$status') ?? 0,
        decoded['body']?.toString() ?? '',
      );
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _loadUrlAndWait(WebViewController controller, String url) async {
    _pageLoadCompleter = Completer<void>();
    await controller.loadRequest(Uri.parse(url));
    await _pageLoadCompleter!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception('Timeout WebView per $url'),
    );
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

  String _escapeJsString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
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

class ScWebViewResponse {
  final int statusCode;
  final String body;

  const ScWebViewResponse(this.statusCode, this.body);
}
