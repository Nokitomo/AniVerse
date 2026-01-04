import 'package:aniverse/services/app_section_controller.dart';
import 'package:aniverse/services/streaming_domain_service.dart';
import 'package:aniverse/services/streamingcommunity_auth_service.dart';
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
  final Map<String, int> _loginAttempts = <String, int>{};
  String? _streamingUnityHost;
  String? _preferredHost;
  bool _showFillButton = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
      )
      ..addJavaScriptChannel(
        'ScLoginAssist',
        onMessageReceived: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _showFillButton = message.message == 'focus';
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: (_) {
            _syncState();
            _maybeAutoLogin();
            _maybeUpdatePreferredHost();
            _setupLoginFieldListeners();
          },
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

  Future<void> _maybeAutoLogin() async {
    final auth = Get.find<StreamingCommunityAuthService>();
    if (!auth.isAutoLoginEnabled()) {
      return;
    }
    final username = auth.getUsername().trim();
    final password = await auth.getPassword();
    if (username.isEmpty || password.isEmpty) {
      return;
    }
    final currentUrl = await _controller.currentUrl();
    if (currentUrl == null || currentUrl.isEmpty) {
      return;
    }
    final attempts = _loginAttempts[currentUrl] ?? 0;
    if (attempts >= 1) {
      return;
    }
    _loginAttempts[currentUrl] = attempts + 1;
    final uri = Uri.tryParse(currentUrl);
    if (uri == null) {
      return;
    }
    final host = uri.host.toLowerCase();
    final baseHost = _baseHost;
    final unityHost = _streamingUnityHost;
    final isStreamingHost = (baseHost != null && _isSameOrSubdomain(host, baseHost)) ||
        (unityHost != null && _isSameOrSubdomain(host, unityHost));
    if (!isStreamingHost) {
      return;
    }
    final hasPasswordField = await _runJsBool(
      "document.querySelector('input[type=\"password\"]') != null",
    );
    if (!hasPasswordField) {
      return;
    }
    _loginAttempts[currentUrl] = attempts + 1;
    final payload = '''
      (() => {
        const userValue = ${_escapeJsString(username)};
        const passValue = ${_escapeJsString(password)};
        const setNativeValue = (element, value) => {
          const proto = Object.getPrototypeOf(element);
          const setter =
            Object.getOwnPropertyDescriptor(proto, 'value')?.set ||
            Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set;
          if (setter) {
            setter.call(element, value);
          } else {
            element.value = value;
          }
          element.setAttribute('value', value);
        };
        const dispatchInput = (element, value) => {
          try {
            element.dispatchEvent(new InputEvent('input', {
              bubbles: true,
              data: value,
              inputType: 'insertText'
            }));
          } catch (_) {
            element.dispatchEvent(new Event('input', { bubbles: true }));
          }
          element.dispatchEvent(new Event('change', { bubbles: true }));
          element.dispatchEvent(new Event('keyup', { bubbles: true }));
        };
        const userSelectors = [
          'input[name=\"email\"]',
          'input[name=\"login\"]',
          'input[name=\"username\"]',
          'input[autocomplete=\"username\"]',
          'input[autocomplete=\"email\"]',
          'input[type=\"email\"]',
          'input[type=\"text\"]'
        ];
        const passSelector = 'input[type=\"password\"]';
        const userInput = userSelectors
          .map(sel => document.querySelector(sel))
          .find(el => el);
        const passInput = document.querySelector(passSelector);
        if (!userInput || !passInput) return false;
        const applyValues = () => {
          userInput.focus();
          setNativeValue(userInput, userValue);
          dispatchInput(userInput, userValue);
          passInput.focus();
          setNativeValue(passInput, passValue);
          dispatchInput(passInput, passValue);
        };
        applyValues();
        let tries = 0;
        const maxTries = 4;
        const ensureValues = () => {
          const u = userInput.value || '';
          const p = passInput.value || '';
          if (u && p) return;
          if (tries >= maxTries) return;
          tries += 1;
          applyValues();
          setTimeout(ensureValues, 300);
        };
        setTimeout(ensureValues, 250);
        const form = passInput.closest('form') || userInput.closest('form');
        const submitButton = form
          ? form.querySelector('button[type=\"submit\"], input[type=\"submit\"]')
          : document.querySelector('button[type=\"submit\"], input[type=\"submit\"]');
        if (submitButton) {
          submitButton.click();
          return true;
        }
        if (form) {
          form.submit();
          return true;
        }
        return false;
      })();
    ''';
    await _controller.runJavaScript(payload);
  }

  Future<void> _setupLoginFieldListeners() async {
    await _controller.runJavaScript('''
      (() => {
        const already = window.__scLoginListenersInstalled;
        if (already) return;
        window.__scLoginListenersInstalled = true;
        const selectors = [
          'input[name="email"]',
          'input[name="login"]',
          'input[name="username"]',
          'input[autocomplete="username"]',
          'input[autocomplete="email"]',
          'input[type="email"]',
          'input[type="password"]'
        ];
        const attach = () => {
          selectors.forEach(sel => {
            document.querySelectorAll(sel).forEach(el => {
              if (el.__scLoginBound) return;
              el.__scLoginBound = true;
              el.addEventListener('focus', () => {
                if (window.ScLoginAssist) {
                  window.ScLoginAssist.postMessage('focus');
                }
              });
              el.addEventListener('blur', () => {
                if (window.ScLoginAssist) {
                  window.ScLoginAssist.postMessage('blur');
                }
              });
            });
          });
        };
        attach();
        const observer = new MutationObserver(() => attach());
        observer.observe(document.documentElement, { childList: true, subtree: true });
      })();
    ''');
  }

  Future<void> _fillCredentials() async {
    final auth = Get.find<StreamingCommunityAuthService>();
    final username = auth.getUsername().trim();
    final password = await auth.getPassword();
    if (username.isEmpty || password.isEmpty) {
      return;
    }
    final payload = '''
      (() => {
        const userValue = ${_escapeJsString(username)};
        const passValue = ${_escapeJsString(password)};
        const setNativeValue = (element, value) => {
          const proto = Object.getPrototypeOf(element);
          const setter =
            Object.getOwnPropertyDescriptor(proto, 'value')?.set ||
            Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set;
          if (setter) {
            setter.call(element, value);
          } else {
            element.value = value;
          }
          element.setAttribute('value', value);
        };
        const dispatchInput = (element, value) => {
          try {
            element.dispatchEvent(new InputEvent('input', {
              bubbles: true,
              data: value,
              inputType: 'insertText'
            }));
          } catch (_) {
            element.dispatchEvent(new Event('input', { bubbles: true }));
          }
          element.dispatchEvent(new Event('change', { bubbles: true }));
          element.dispatchEvent(new Event('keyup', { bubbles: true }));
        };
        const userSelectors = [
          'input[name="email"]',
          'input[name="login"]',
          'input[name="username"]',
          'input[autocomplete="username"]',
          'input[autocomplete="email"]',
          'input[type="email"]',
          'input[type="text"]'
        ];
        const passSelector = 'input[type="password"]';
        const userInput = userSelectors
          .map(sel => document.querySelector(sel))
          .find(el => el);
        const passInput = document.querySelector(passSelector);
        if (!userInput || !passInput) return false;
        userInput.focus();
        setNativeValue(userInput, userValue);
        dispatchInput(userInput, userValue);
        passInput.focus();
        setNativeValue(passInput, passValue);
        dispatchInput(passInput, passValue);
        return true;
      })();
    ''';
    await _controller.runJavaScript(payload);
  }

  Future<void> _maybeUpdatePreferredHost() async {
    final auth = Get.find<StreamingCommunityAuthService>();
    final currentUrl = await _controller.currentUrl();
    if (currentUrl == null || currentUrl.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(currentUrl);
    if (uri == null) {
      return;
    }
    final host = uri.host.toLowerCase();
    if (!_isAllowedHost(host)) {
      return;
    }
    final loggedIn = await _runJsBool(
      '''
      (() => {
        const logoutLink = Array.from(document.querySelectorAll('a'))
          .some(el => {
            const href = (el.getAttribute('href') || '').toLowerCase();
            const text = (el.textContent || '').toLowerCase();
            return href.includes('logout') || text.includes('logout') || text.includes('esci');
          });
        const userMenu = document.querySelector('[data-testid*="user"], .user-menu, .user-dropdown, .dropdown-user');
        return Boolean(logoutLink || userMenu);
      })();
      ''',
    );
    if (!loggedIn) {
      return;
    }
    final unityHost = _streamingUnityHost;
    final preferUnity = auth.isAutoLoginEnabled() && unityHost != null && unityHost.isNotEmpty;
    final targetHost = preferUnity ? unityHost : host;
    if (_preferredHost != targetHost) {
      _preferredHost = targetHost;
      await auth.setPreferredHost(targetHost);
    }
  }

  Future<bool> _runJsBool(String script) async {
    final result = await _controller.runJavaScriptReturningResult(script);
    if (result is bool) {
      return result;
    }
    final normalized = result.toString().toLowerCase();
    return normalized == 'true';
  }

  String _escapeJsString(String value) {
    return "'${value.replaceAll(r'\\', r'\\\\').replaceAll("'", r"\\'")}'";
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
    });
    final baseUrl = await getStreamingCommunityBaseUrl();
    final unityUrl = await getStreamingUnityBaseUrl();
    _streamingUnityHost = Uri.parse(unityUrl).host.toLowerCase();
    _baseHost = Uri.parse(baseUrl).host.toLowerCase();
    final auth = Get.find<StreamingCommunityAuthService>();
    final preferredHost = auth.getPreferredHost().trim();
    if (preferredHost.isNotEmpty) {
      _preferredHost = preferredHost.toLowerCase();
      _homeUrl = 'https://$_preferredHost/';
    } else if (auth.isAutoLoginEnabled()) {
      _homeUrl = '$unityUrl/';
    } else {
      _homeUrl = '$baseUrl/';
    }
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
    final unityHost = _streamingUnityHost;
    if (unityHost != null && _isSameOrSubdomain(host, unityHost)) {
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
              if (_showFillButton)
                IconButton(
                  tooltip: 'Compila credenziali',
                  onPressed: _fillCredentials,
                  icon: const Icon(Icons.vpn_key),
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
