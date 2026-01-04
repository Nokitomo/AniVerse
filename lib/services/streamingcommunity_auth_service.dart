import 'package:aniverse/services/internal_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

class StreamingCommunityAuthService {
  static const String _usernameKey = 'sc_username';
  static const String _autoLoginKey = 'sc_autologin_enabled';
  static const String _passwordKey = 'sc_password';
  static const String _preferredHostKey = 'sc_preferred_host';

  final InternalAPI _internalApi = Get.find<InternalAPI>();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String getUsername() {
    return _internalApi.getKeyValue(_usernameKey);
  }

  Future<void> setUsername(String value) async {
    _internalApi.setKeyValue(_usernameKey, value);
  }

  bool isAutoLoginEnabled() {
    final raw = _internalApi.getKeyValue(_autoLoginKey);
    return raw == 'true';
  }

  Future<void> setAutoLoginEnabled(bool value) async {
    _internalApi.setKeyValue(_autoLoginKey, value.toString());
  }

  String getPreferredHost() {
    return _internalApi.getKeyValue(_preferredHostKey);
  }

  Future<void> setPreferredHost(String value) async {
    _internalApi.setKeyValue(_preferredHostKey, value);
  }

  Future<String> getPassword() async {
    try {
      return await _secureStorage.read(key: _passwordKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setPassword(String value) async {
    try {
      if (value.isEmpty) {
        await _secureStorage.delete(key: _passwordKey);
      } else {
        await _secureStorage.write(key: _passwordKey, value: value);
      }
    } catch (_) {
      // ignore storage errors to avoid blocking settings UI
    }
  }
}
