import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_helper.dart';

class ProfileStore extends ChangeNotifier {
  ProfileStore(this._database, {Future<Directory> Function()? storageRoot})
    : _storageRoot = storageRoot ?? getApplicationSupportDirectory;

  final DatabaseHelper _database;
  final Future<Directory> Function() _storageRoot;
  Uint8List? _avatar;
  String? _originalPath;
  String _name = 'Guest';
  String? _email;
  bool _isGuest = true;
  int? _userId;
  bool _saving = false;
  bool _disposed = false;

  DatabaseHelper get database => _database;
  Uint8List? get avatar => _avatar;
  String? get originalPath => _originalPath;
  String get name => _name;
  String? get email => _email;
  bool get isGuest => _isGuest;
  int? get userId => _userId;
  bool get saving => _saving;

  Future<void> load() async {
    await _database.ensureDefaultCategory();
    final id = await _database.workspaceUserId();
    _userId = id;
    final database = await _database.database;
    final userRows = await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (userRows.isNotEmpty) {
      _email = userRows.single['google_email'] as String?;
      _isGuest = userRows.single['google_account_id'] == null;
    } else {
      _email = null;
      _isGuest = true;
    }
    final rows = await database.query(
      'profiles',
      where: 'user_id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      _name = _isGuest ? 'Guest' : (_email ?? 'Google User');
      _avatar = null;
      _originalPath = null;
    } else {
      final row = rows.single;
      final savedName = row['display_name'] as String?;
      _name = !_isGuest && (savedName == null || savedName == 'Guest')
          ? (_email ?? 'Google account')
          : (savedName ?? 'Guest');
      _avatar = row['avatar_image'] as Uint8List?;
      _originalPath = row['avatar_original_path'] as String?;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setAvatar(Uint8List? bytes, {Uint8List? original}) async {
    if (_saving) return;
    _saving = true;
    if (!_disposed) notifyListeners();
    String? staged;
    try {
      if (bytes != null && original != null) {
        staged = await writeOriginal(await _storageRoot(), original);
      }
      final database = await _database.database;
      final userId = await _database.workspaceUserId();
      final previous = await database.transaction((txn) async {
        final profiles = await txn.query(
          'profiles',
          columns: ['avatar_original_path'],
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        final values = {'avatar_image': bytes, 'avatar_original_path': staged};
        final updated = await txn.update(
          'profiles',
          values,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        if (updated == 0) {
          await txn.insert('profiles', {
            'user_id': userId,
            'display_name': 'Guest',
            'created_at': DateTime.now().toIso8601String(),
            ...values,
          });
        }
        return profiles.singleOrNull?['avatar_original_path'] as String?;
      });
      _avatar = bytes;
      _originalPath = staged;
      staged = null;
      await _removeOriginal(previous);
    } finally {
      await _removeOriginal(staged);
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setName(String name) async {
    final value = name.trim();
    if (value.isEmpty || _saving) return;
    _saving = true;
    try {
      final id = await _database.workspaceUserId();
      final db = await _database.database;
      await db.update(
        'profiles',
        {'display_name': value},
        where: 'user_id = ?',
        whereArgs: [id],
      );
      _name = value;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<String> writeOriginal(
    Directory support,
    List<int> bytes,
  ) async {
    final root = Directory(p.join(support.path, 'profile_photos'));
    await root.create(recursive: true);
    final folder = await root.createTemp('photo_');
    final file = File(p.join(folder.path, 'original'));
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _removeOriginal(String? path) async {
    if (path == null) return;
    try {
      await removeOriginal(await _storageRoot(), path);
    } on Exception catch (error) {
      debugPrint('Could not clean up a profile photo: $error');
    }
  }

  static Future<void> removeOriginal(Directory support, String? path) async {
    if (path == null) return;
    try {
      final root = p.join(support.path, 'profile_photos');
      final folder = p.dirname(p.normalize(path));
      if (!p.equals(p.dirname(folder), root) ||
          !p.basename(folder).startsWith('photo_') ||
          p.basename(path) != 'original') {
        return;
      }
      final file = File(path);
      if (await file.exists()) await file.delete();
      final directory = Directory(folder);
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    } on Exception catch (error) {
      debugPrint('Could not clean up a profile photo: $error');
    }
  }
}
