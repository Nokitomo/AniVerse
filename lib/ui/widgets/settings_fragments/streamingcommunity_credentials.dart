import 'package:aniverse/services/streamingcommunity_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StreamingCommunityCredentials extends StatefulWidget {
  const StreamingCommunityCredentials({super.key});

  @override
  State<StreamingCommunityCredentials> createState() =>
      _StreamingCommunityCredentialsState();
}

class _StreamingCommunityCredentialsState
    extends State<StreamingCommunityCredentials> {
  final StreamingCommunityAuthService _authService =
      Get.find<StreamingCommunityAuthService>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _autoLogin = false;
  bool _loading = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final username = _authService.getUsername();
    final password = await _authService.getPassword();
    final autoLogin = _authService.isAutoLoginEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
      _autoLogin = autoLogin;
      _loading = false;
    });
  }

  Future<void> _saveValues() async {
    await _authService.setUsername(_usernameController.text.trim());
    await _authService.setPassword(_passwordController.text);
    await _authService.setAutoLoginEnabled(_autoLogin);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'StreamingCommunity',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Salva le credenziali per eseguire il login automatico.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _saveValues(),
            decoration: const InputDecoration(
              labelText: 'Username o Email',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (_) => _saveValues(),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Login automatico'),
            value: _autoLogin,
            onChanged: (value) {
              setState(() {
                _autoLogin = value;
              });
              _saveValues();
            },
          ),
        ],
      ),
    );
  }
}
