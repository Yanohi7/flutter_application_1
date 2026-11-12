abstract final class GoogleOAuthConfig {
  static const desktopClientId = String.fromEnvironment(
    'ENTRIES_GOOGLE_DESKTOP_CLIENT_ID',
  );
  static const desktopClientSecret = String.fromEnvironment(
    'ENTRIES_GOOGLE_DESKTOP_CLIENT_SECRET',
  );

  static const webClientId =
      '689430413316-jv0nt8upvc67gnhg1gt4unrjsq0i0ia3.apps.googleusercontent.com';
}
