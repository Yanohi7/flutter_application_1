import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    as platform;
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../config/google_oauth_config.dart';
import 'desktop_google_account.dart';
import 'drive_workspace_store.dart';

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
  final _http = http.Client();

  Future<void>? _initialization;

  GoogleSignInAccount? _account;
  WorkspaceGoogleAccount? _androidAccount;
  Map<String, String>? _androidHeaders;
  String? _verifiedAndroidToken;

  WorkspaceGoogleAccount? get account {
    if (_androidAccount case final android?) return android;
    final user = _account;
    return user == null
        ? _desktopAccount?.account
        : (id: user.id, email: user.email);
  }

  static const _scopes = [GoogleDriveConfig.appDataScope];
  static const _androidScopes = [..._scopes, 'openid', 'email'];
  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _initialize() async {
    _initialization ??= _google.initialize(
      clientId: _appleClientId,
      serverClientId: defaultTargetPlatform == TargetPlatform.android
          ? GoogleOAuthConfig.webClientId
          : null,
    );

    await _initialization;
  }

  Future<WorkspaceGoogleAccount> signIn({
    String? expectedId,
    String? expectedEmail,
    bool chooseAccount = false,
  }) async {
    final desktop = _desktopAccount;
    if (desktop != null) {
      return desktop.signIn(
        expectedId: expectedId,
        expectedEmail: expectedEmail,
      );
    }
    if (_android && expectedId != null && expectedEmail != null) {
      final user = await _authorizeAndroid(
        expectedId,
        expectedEmail,
        interactive: true,
      );
      if (user != null) return user;
      throw const DriveSyncException(
        'Google Drive access is required. Reconnect and allow access.',
      );
    }
    await _initialize();

    final current = _account;
    final user = !chooseAccount && current != null && current.id == expectedId
        ? current
        : await _authenticate();
    if (expectedId != null && user.id != expectedId) {
      await signOut();
      throw const DriveSyncException(
        'Choose the Google account for this workspace.',
      );
    }

    _account = user;
    if (_android) {
      if (await _authorizeAndroid(user.id, user.email, interactive: true) ==
          null) {
        throw const DriveSyncException(
          'Google Drive access is required. Reconnect and allow access.',
        );
      }
    } else {
      await user.authorizationClient.authorizeScopes(_scopes);
    }

    return (id: user.id, email: user.email);
  }

  Future<GoogleSignInAccount> _authenticate() async {
    await signOut();
    return _google.authenticate();
  }

  Future<WorkspaceGoogleAccount?> restore({
    required String expectedId,
    String? expectedEmail,
  }) async {
    final desktop = _desktopAccount;
    if (desktop != null) return desktop.restore(expectedId: expectedId);
    if (_android) {
      if (expectedEmail == null) return null;
      return _authorizeAndroid(expectedId, expectedEmail, interactive: false);
    }
    await _initialize();
    final attempt = _google.attemptLightweightAuthentication();
    _account = attempt == null ? null : await attempt;
    return account;
  }

  Future<WorkspaceGoogleAccount?> _authorizeAndroid(
    String expectedId,
    String email, {
    required bool interactive,
  }) async {
    await _initialize();
    final token = await platform.GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          platform.ClientAuthorizationTokensForScopesParameters(
            request: platform.AuthorizationRequestDetails(
              scopes: _androidScopes,
              userId: expectedId,
              email: email,
              promptIfUnauthorized: interactive,
            ),
          ),
        );
    if (token == null) return null;
    final headers = {'Authorization': 'Bearer ${token.accessToken}'};
    final cached = _androidAccount;
    if (_verifiedAndroidToken == token.accessToken &&
        cached?.id == expectedId) {
      _androidHeaders = headers;
      return cached;
    }
    final response = await _http
        .get(
          Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      await platform.GoogleSignInPlatform.instance.clearAuthorizationToken(
        platform.ClearAuthorizationTokenParams(accessToken: token.accessToken),
      );
      return null;
    }
    if (response.statusCode != 200) {
      throw const DriveSyncException(
        'Could not connect your Google account. Try again.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['sub'] != expectedId) {
      throw const DriveSyncException(
        'Choose the Google account for this workspace.',
      );
    }
    _verifiedAndroidToken = token.accessToken;
    _androidHeaders = headers;
    return _androidAccount = (
      id: expectedId,
      email: data['email'] as String? ?? email,
    );
  }

  Future<bool> ensureDriveAccess({
    required String expectedId,
    required bool justRestored,
  }) async {
    final current = account;
    if (current == null || current.id != expectedId) return false;
    if (_android) {
      if (justRestored && _androidHeaders != null) return true;
      _androidHeaders = null;
      return await _authorizeAndroid(
            expectedId,
            current.email,
            interactive: false,
          ) !=
          null;
    }
    await authorizationHeaders();
    return true;
  }

  Future<Map<String, String>> authorizationHeaders() async {
    final desktop = _desktopAccount;
    if (desktop != null) return desktop.authorizationHeaders();
    if (_android) {
      return _androidHeaders ??
          (throw StateError(
            'Google Drive access is required. Please reconnect.',
          ));
    }
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
    _androidAccount = null;
    _androidHeaders = null;
    _verifiedAndroidToken = null;
  }

  void close() {
    _desktopAccount?.close();
    _http.close();
  }
}
