import 'dart:convert';

/// The plaintext inside an encrypted private field.
class PrivateEntryContent {
  const PrivateEntryContent(this.text, {this.login = '', this.password = ''});

  static const _marker = '\u0000entrynote:private-content:1\n';

  final String text;
  final String login;
  final String password;

  bool get hasCredentials => login.isNotEmpty || password.isNotEmpty;

  String encode() {
    if (!hasCredentials && !text.startsWith(_marker)) return text;
    return '$_marker${jsonEncode({'text': text, 'login': login, 'password': password})}';
  }

  static PrivateEntryContent decode(String value) {
    if (value.startsWith(_marker)) {
      try {
        if (jsonDecode(value.substring(_marker.length)) case {
          'text': final String text,
          'login': final String login,
          'password': final String password,
        }) {
          return PrivateEntryContent(text, login: login, password: password);
        }
      } on FormatException {
        // Keep existing private text readable, including malformed metadata.
      }
    }
    return PrivateEntryContent(value);
  }
}
