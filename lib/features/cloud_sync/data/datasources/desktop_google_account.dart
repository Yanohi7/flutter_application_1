import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/google_drive_config.dart';
import '../config/google_oauth_config.dart';
import 'drive_workspace_store.dart';

typedef WorkspaceGoogleAccount = ({String id, String email});

class DesktopGoogleAccount {
  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  static const _scopes = ['openid', 'email', GoogleDriveConfig.appDataScope];
  static const _clientId = GoogleOAuthConfig.desktopClientId;
  static const _clientSecret = GoogleOAuthConfig.desktopClientSecret;
  static const _storageKey = 'entries_google_refresh_$_clientId';
  static const _timeout = Duration(seconds: 30);
  final _http = http.Client();
  WorkspaceGoogleAccount? account;
  String? _refreshToken;
  AccessToken? _accessToken;

  Future<WorkspaceGoogleAccount> signIn() async {
    final verifier = _randomValue();
    final state = _randomValue();
    final challenge = _base64Url(
      (await Sha256().hash(ascii.encode(verifier))).bytes,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}/oauth';
    late String code;
    try {
      final authorization = Uri.https(
        'accounts.google.com',
        '/o/oauth2/v2/auth',
        {
          'client_id': _clientId,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': _scopes.join(' '),
          'access_type': 'offline',
          'prompt': 'consent select_account',
          'code_challenge_method': 'S256',
          'code_challenge': challenge,
          'state': state,
        },
      );
      if (!await launchUrl(
        authorization,
        mode: LaunchMode.externalApplication,
      )) {
        throw const DriveSyncException(
          'Could not open the browser for Google sign-in.',
        );
      }
      final request = await server
          .firstWhere((request) {
            if (request.method == 'GET' &&
                request.uri.path == '/oauth' &&
                request.uri.queryParameters['state'] == state) {
              return true;
            }
            request.response.statusCode = HttpStatus.notFound;
            unawaited(request.response.close());
            return false;
          })
          .timeout(const Duration(minutes: 2));
      request.response
        ..headers.contentType = ContentType.text
        ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
        ..write(
          'Return to EntryNote to finish connecting your Google account.',
        );
      await request.response.close();
      code = request.uri.queryParameters['code'] ?? '';
      if (code.isEmpty) {
        throw const DriveSyncException(
          'Google sign-in was canceled or denied.',
        );
      }
    } finally {
      await server.close(force: true);
    }

    final response = await _http
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          body: {
            'client_id': _clientId,
            if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
            'code': code,
            'code_verifier': verifier,
            'redirect_uri': redirect,
            'grant_type': 'authorization_code',
          },
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw const DriveSyncException(
        'Google could not complete sign-in. Check the Desktop OAuth client configuration.',
      );
    }
    final tokens = jsonDecode(response.body) as Map<String, dynamic>;
    final refresh = tokens['refresh_token'] as String?;
    final access = tokens['access_token'] as String?;
    final duration = tokens['expires_in'] as int?;
    final scopes = (tokens['scope'] as String? ?? '').split(' ');
    if (refresh == null ||
        access == null ||
        duration == null ||
        !scopes.contains(GoogleDriveConfig.appDataScope)) {
      throw const DriveSyncException(
        'Google Drive access is required. Reconnect and allow access.',
      );
    }
    final user = await _userInfo(access);
    await _storage.write(key: _storageKey, value: refresh);
    _refreshToken = refresh;
    _accessToken = AccessToken(
      'Bearer',
      access,
      DateTime.now().toUtc().add(Duration(seconds: duration)),
    );
    return account = user;
  }

  Future<WorkspaceGoogleAccount?> restore() async {
    final refresh = await _storage.read(key: _storageKey);
    if (refresh == null) return null;
    _refreshToken = refresh;
    try {
      final headers = await authorizationHeaders();
      return account = await _userInfo(headers['Authorization']!.substring(7));
    } on AccessDeniedException {
      await signOut();
      return null;
    }
  }

  Future<Map<String, String>> authorizationHeaders() async {
    var token = _accessToken;
    if (token == null || token.hasExpired) {
      final refresh = _refreshToken;
      if (refresh == null) throw StateError('Sign in with Google first.');
      final credentials = await refreshCredentials(
        ClientId(_clientId, _clientSecret.isEmpty ? null : _clientSecret),
        AccessCredentials(
          token ??
              AccessToken(
                'Bearer',
                '',
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              ),
          refresh,
          _scopes,
        ),
        _http,
      ).timeout(_timeout);
      token = credentials.accessToken;
      _accessToken = token;
    }
    return {'Authorization': 'Bearer ${token.data}'};
  }

  Future<WorkspaceGoogleAccount> _userInfo(String token) async {
    final response = await _http
        .get(
          Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw const DriveSyncException(
        'Could not read your Google account. Reconnect and try again.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (id: data['sub'] as String, email: data['email'] as String);
  }

  Future<void> signOut() async {
    await _storage.delete(key: _storageKey);
    _accessToken = null;
    _refreshToken = null;
    account = null;
  }

  void close() => _http.close();

  static String _randomValue() {
    final random = Random.secure();
    return _base64Url(List.generate(32, (_) => random.nextInt(256)));
  }

  static String _base64Url(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');
}
