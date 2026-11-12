import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_drive_config.dart';
import '../config/google_oauth_config.dart';
import 'desktop_google_account.dart';

class GoogleAccountRemoteDataSource {
  static const _configuration = MethodChannel('entries/google_config');
  static String? _appleClientId;
  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<bool> isSupported() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    if (_desktop) return _validClientId(GoogleOAuthConfig.desktopClientId);
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    try {
      final config = await _configuration.invokeMapMethod<String, Object?>(
        'configuration',
      );
      final clientId = config?['clientId'];
      final schemes = config?['schemes'];
      if (clientId is String &&
          _validClientId(clientId) &&
          schemes is List &&
          schemes.contains(clientId.split('.').reversed.join('.'))) {
        _appleClientId = clientId;
        return true;
      }
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
    return false;
  }

  static bool _validClientId(String value) =>
      RegExp(r'^[a-zA-Z0-9-]+\.apps\.googleusercontent\.com$').hasMatch(value);

  final GoogleSignIn _google = GoogleSignIn.instance;
  final _desktopAccount = _desktop ? DesktopGoogleAccount() : null;

  Future<void>? _initialization;

  GoogleSignInAccount? _account;

  WorkspaceGoogleAccount? get account {
    final user = _account;
    return user == null
        ? _desktopAccount?.account
        : (id: user.id, email: user.email);
  }

  static const _scopes = [GoogleDriveConfig.appDataScope];

  Future<void> _initialize() async {
    _initialization ??= _google.initialize(
      clientId: _appleClientId,
      serverClientId: defaultTargetPlatform == TargetPlatform.android
          ? GoogleOAuthConfig.webClientId
          : null,
    );

    await _initialization;
  }

  Future<WorkspaceGoogleAccount> signIn() async {
    final desktop = _desktopAccount;
    if (desktop != null) return desktop.signIn();
    await _initialize();

    final user = await _google.authenticate();

    await user.authorizationClient.authorizeScopes(_scopes);

    _account = user;

    return (id: user.id, email: user.email);
  }

  Future<WorkspaceGoogleAccount?> restore() async {
    final desktop = _desktopAccount;
    if (desktop != null) return desktop.restore();
    await _initialize();
    final attempt = _google.attemptLightweightAuthentication();
    _account = attempt == null ? null : await attempt;
    return account;
  }

  Future<Map<String, String>> authorizationHeaders() async {
    final desktop = _desktopAccount;
    if (desktop != null) return desktop.authorizationHeaders();
    final user = _account;

    if (user == null) {
      throw StateError('Sign in with Google first.');
    }

    final authorization = await user.authorizationClient.authorizationForScopes(
      _scopes,
    );

    if (authorization == null) {
      throw StateError('Google Drive access is required. Please reconnect.');
    }

    return {'Authorization': 'Bearer ${authorization.accessToken}'};
  }

  Future<void> signOut() async {
    final desktop = _desktopAccount;
    if (desktop != null) return desktop.signOut();
    await _initialize();
    await _google.signOut();

    _account = null;
  }

  void close() => _desktopAccount?.close();
}
