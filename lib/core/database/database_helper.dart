// Open and migrate SQLite, define its tables and ensure the local default category exists

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'entries_database_migration.dart';

class LocalUserAccount {
  final int id;
  final String? googleAccountId;
  final String? googleEmail;
  final String displayName;
  final Uint8List? avatar;
  final String? avatarOriginalPath;
  final String createdAt;

  const LocalUserAccount({
    required this.id,
    this.googleAccountId,
    this.googleEmail,
    required this.displayName,
    this.avatar,
    this.avatarOriginalPath,
    required this.createdAt,
  });

  bool get isGuest => googleAccountId == null;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  Database? _database; // Each helper owns its connection
  Future<Database>?
  _opening; // Concurrent requests share the same opening operation
  final String? _databasePath;
  final DatabaseHelper? _source;
  final int? userId;
  String get _activeUserKey => _databasePath == null
      ? 'entries_active_user_id'
      : 'entries_active_user_id_$_databasePath';
  int? _activeUserId;

  int? get activeUserId => userId ?? _activeUserId;
  DatabaseHelper._init() : _databasePath = null, _source = null, userId = null;

  // Tests use a separate database and never delete app entries
  DatabaseHelper.forTesting(String databasePath)
    : _databasePath = databasePath,
      _source = null,
      userId = null;

  DatabaseHelper.forUser(DatabaseHelper source, this.userId)
    : _source = source,
      _databasePath = null;

  Future<Database> get database async {
    if (_source case final source?) return source.database;
    if (_database != null) return _database!;
    try {
      _opening ??= _initDB();
      _database = await _opening;
      return _database!;
    } catch (_) {
      _opening =
          null; // After an error, Try again attempts to open the database again
      rethrow;
    }
  }

  Future<String> _resolvePath() async {
    if (_databasePath case final String path) return path;
    final oldDirectory = await getDatabasesPath();
    final desktop = Platform.isWindows || Platform.isLinux;
    final directory = desktop
        ? (await getApplicationSupportDirectory()).path
        : oldDirectory;

    return prepareEntriesDatabase(
      destination: join(directory, 'entries.db'),
      legacyPaths: [
        join(oldDirectory, 'test_database.db'),
        if (desktop) ..._desktopLegacyPaths(),
      ],
    );
  }

  Iterable<String> _desktopLegacyPaths() sync* {
    final executable = File(Platform.resolvedExecutable).parent;
    String legacyIn(Directory folder) => join(
      folder.path,
      '.dart_tool',
      'sqflite_common_ffi',
      'databases',
      'test_database.db',
    );

    yield legacyIn(executable);
    // A Windows or Linux build may have been started with the project as its cwd.
    for (
      var folder = executable;
      folder.path != folder.parent.path;
      folder = folder.parent
    ) {
      if (basename(folder.path) == 'build' &&
          File(join(folder.parent.path, 'pubspec.yaml')).existsSync()) {
        yield legacyIn(folder.parent);
        break;
      }
    }
  }

  Future<Database> _initDB() async {
    final path = await _resolvePath();
    return await openDatabase(
      path,
      version: 10,
      // Enable SQLite relationship checks on every opened connection
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Allow reusing names from soft-deleted categories when upgrading an existing database
        if (oldVersion < 2) {
          await db.execute('DROP INDEX IF EXISTS idx_categories_root_name;');
          await db.execute('DROP INDEX IF EXISTS idx_categories_sub_name;');

          await db.execute(
            'CREATE UNIQUE INDEX idx_categories_root_name '
            'ON categories (user_id, name) '
            'WHERE parent_id IS NULL AND is_deleted = 0;',
          );

          await db.execute(
            'CREATE UNIQUE INDEX idx_categories_sub_name '
            'ON categories (user_id, parent_id, name) '
            'WHERE parent_id IS NOT NULL AND is_deleted = 0;',
          );
        }
        // Preserve existing attachments while adding optional user labels
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE media_attachments ADD COLUMN display_name TEXT;',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE entries ADD COLUMN private_content TEXT NOT NULL DEFAULT '';",
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE profiles ADD COLUMN avatar_image BLOB;',
          );
        }
        if (oldVersion < 6) {
          final avatars = await db.query(
            'profiles',
            columns: ['id', 'avatar_path'],
            where: 'avatar_image IS NULL AND avatar_path IS NOT NULL',
          );
          for (final avatar in avatars) {
            final file = File(avatar['avatar_path'] as String);
            try {
              if (await file.length() <= 2 * 1024 * 1024) {
                await db.update(
                  'profiles',
                  {'avatar_image': await file.readAsBytes()},
                  where: 'id = ?',
                  whereArgs: [avatar['id']],
                );
              }
            } on FileSystemException {
              // The old path may point to a photo that is no longer available.
            }
          }
          // Earlier schemas created placeholder tables even without an active feature.
          // Retain any non-default legacy data that might have been added outside the app.
          const unusedTables = {
            'settings':
                "language IN ('uk', 'en') AND theme = 'light' "
                "AND notifications_enabled = 1 AND sort_type = 'date' "
                'AND sort_ascending = 1',
            'premium_status':
                'is_active = 0 AND activated_at IS NULL AND expires_at IS NULL',
            'structured_elements': '0',
            'sync_metadata':
                "remote_id IS NULL AND is_synced = 0 AND sync_status = 'local_only' "
                'AND last_synced_at IS NULL AND deleted_at IS NULL',
          };
          for (final MapEntry(key: table, value: placeholder)
              in unusedTables.entries) {
            final exists = await db.query(
              'sqlite_master',
              where: "type = 'table' AND name = ?",
              whereArgs: [table],
            );
            if (exists.isNotEmpty &&
                (await db.query(
                  table,
                  columns: ['id'],
                  where: 'NOT ($placeholder)',
                  limit: 1,
                )).isEmpty) {
              await db.execute('DROP TABLE $table');
            }
          }
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE profiles ADD COLUMN avatar_original_path TEXT;',
          );
        }
        if (oldVersion < 8) await _addAccountColumns(db);
        if (oldVersion < 9) await _createGuestTransfer(db);
        if (oldVersion < 10) await _createPrivateKeyTable(db);
      },
    );
  }

  Future<int> initActiveUser() async {
    final prefs = SharedPreferencesAsync();
    final savedId = await prefs.getInt(_activeUserKey);
    final db = await database;
    if (savedId != null) {
      final exists = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [savedId],
        limit: 1,
      );
      if (exists.isNotEmpty) {
        _activeUserId = savedId;
        return savedId;
      }
    }
    await ensureDefaultCategory();
    final guestId = await workspaceUserId();
    _activeUserId = guestId;
    return guestId;
  }

  Future<void> switchUser(int id) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setInt(_activeUserKey, id);
    _activeUserId = id;
  }

  Future<List<LocalUserAccount>> getLocalAccounts() async {
    await guestUserId();
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT users.id, users.google_account_id, users.google_email, users.created_at,
             profiles.display_name, profiles.avatar_image, profiles.avatar_original_path
      FROM users
      LEFT JOIN profiles ON users.id = profiles.user_id
      ORDER BY CASE WHEN users.google_account_id IS NULL THEN 0 ELSE 1 END, users.id ASC
    ''');
    return rows.map((r) {
      final googleId = r['google_account_id'] as String?;
      final email = r['google_email'] as String?;
      final name = r['display_name'] as String?;
      return LocalUserAccount(
        id: r['id'] as int,
        googleAccountId: googleId,
        googleEmail: email,
        displayName:
            (name?.trim().isNotEmpty == true &&
                (name != 'Guest' || googleId == null))
            ? name!.trim()
            : (googleId == null ? 'Guest' : (email ?? 'Google account')),
        avatar: r['avatar_image'] as Uint8List?,
        avatarOriginalPath: r['avatar_original_path'] as String?,
        createdAt: r['created_at'] as String? ?? '',
      );
    }).toList();
  }

  Future<int> guestUserId() =>
      DatabaseHelper.forUser(this, null).workspaceUserId();

  Future<LocalUserAccount> getOrCreateGoogleAccount({
    required String googleAccountId,
    required String email,
    String? displayName,
    Uint8List? avatar,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final existing = await txn.query(
        'users',
        where: 'google_account_id = ?',
        whereArgs: [googleAccountId],
        limit: 1,
      );
      final int resolvedUserId;
      if (existing.isNotEmpty) {
        resolvedUserId = existing.first['id'] as int;
        await txn.update(
          'users',
          {'google_email': email},
          where: 'id = ?',
          whereArgs: [resolvedUserId],
        );
      } else {
        resolvedUserId = await txn.insert('users', {
          'google_account_id': googleAccountId,
          'google_email': email,
          'created_at': now,
        });
        final name = displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : 'Guest';
        await txn.insert('profiles', {
          'user_id': resolvedUserId,
          'display_name': name,
          'avatar_image': avatar,
          'created_at': now,
        });
        await txn.insert('categories', {
          'user_id': resolvedUserId,
          'name': 'General',
          'is_system': 1,
          'is_default': 1,
          'created_at': now,
          'updated_at': now,
        });
      }
      final prof = await txn.query(
        'profiles',
        where: 'user_id = ?',
        whereArgs: [resolvedUserId],
        limit: 1,
      );
      final profRow = prof.singleOrNull;
      return LocalUserAccount(
        id: resolvedUserId,
        googleAccountId: googleAccountId,
        googleEmail: email,
        displayName: (profRow?['display_name'] as String?) ?? email,
        avatar: profRow?['avatar_image'] as Uint8List?,
        avatarOriginalPath: profRow?['avatar_original_path'] as String?,
        createdAt: now,
      );
    });
  }

  /// Prepare the minimum data for the first entry without clearing existing tables
  Future<int> ensureDefaultCategory() async {
    final db = await database;
    // The transaction commits all inserts together or rolls them all back
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final currentId = activeUserId;
      final users = await txn.query(
        'users',
        where: currentId == null ? 'google_account_id IS NULL' : 'id = ?',
        whereArgs: [?currentId],
        orderBy: 'id ASC',
        limit: 1,
      );
      final int resolvedUserId;
      if (users.isEmpty) {
        if (currentId != null) throw StateError('Local account not found.');
        resolvedUserId = await txn.insert('users', {'created_at': now});
        await txn.insert('profiles', {
          'user_id': resolvedUserId,
          'display_name': 'Guest',
          'created_at': now,
        });
      } else {
        resolvedUserId = users.first['id'] as int;
      }
      final defaults = await txn.query(
        'categories',
        where: 'user_id = ? AND is_default = 1',
        whereArgs: [resolvedUserId],
        limit: 1,
      );
      if (defaults.isNotEmpty) {
        final id = defaults.first['id'] as int;
        // Keep the system category available for new entries
        await txn.update(
          'categories',
          {'is_deleted': 0, 'deleted_at': null},
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }
      final existing = await txn.query(
        'categories',
        where: 'user_id = ? AND parent_id IS NULL AND name = ?',
        whereArgs: [resolvedUserId, 'General'],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        // Reuse a category with the same name instead of creating a duplicate
        await txn.update(
          'categories',
          {
            'is_default': 1,
            'is_system': 1,
            'is_deleted': 0,
            'deleted_at': null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }
      return txn.insert('categories', {
        'user_id': resolvedUserId,
        'name': 'General',
        'is_system': 1,
        'is_default': 1,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  /// Close the connection, including between file-reopening tests
  Future<void> close() async {
    if (_source != null) return;
    final opened = _database ?? (await _opening);
    await opened?.close();
    _database = null;
    _opening = null;
  }

  Future<void> _createDB(Database db, int version) async {
    // Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL
      );
    ''');

    // Profiles
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        avatar_image BLOB NULL,
        avatar_original_path TEXT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
      );
    ''');

    // A parent ID builds the tree and the composite foreign key keeps parents within one user
    // Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        parent_id INTEGER NULL,
        is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)),
        is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
        deleted_at TEXT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (user_id, id),
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (user_id, parent_id) REFERENCES categories (user_id, id) ON DELETE CASCADE ON UPDATE CASCADE
      );
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX idx_categories_root_name '
      'ON categories (user_id, name) '
      'WHERE parent_id IS NULL AND is_deleted = 0;',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_categories_sub_name '
      'ON categories (user_id, parent_id, name) '
      'WHERE parent_id IS NOT NULL AND is_deleted = 0;',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_categories_single_default ON categories (user_id) WHERE is_default = 1;',
    );

    // Entries reference an existing category and store soft-deletion flags rather than removing rows
    // Entries
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        title TEXT NULL,
        content TEXT NOT NULL,
        private_content TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0 CHECK (is_pinned IN (0, 1)),
        is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
        is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
        deleted_at TEXT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT ON UPDATE CASCADE
      );
    ''');

    await db.execute(
      'CREATE INDEX idx_entries_category ON entries (category_id, is_deleted);',
    );

    await db.execute('''
      CREATE TABLE media_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        file_type TEXT NOT NULL CHECK (file_type IN ('photo', 'audio', 'video', 'document')),
        file_name TEXT NOT NULL,
        display_name TEXT,
        local_path TEXT NOT NULL,
        mime_type TEXT NULL,
        file_size INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
        deleted_at TEXT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE ON UPDATE CASCADE
      );
    ''');

    await db.execute(
      'CREATE INDEX idx_media_entry ON media_attachments (entry_id);',
    );
    await _addAccountColumns(db);
    await _createGuestTransfer(db);
    await _createPrivateKeyTable(db);
  }

  Future<void> _createPrivateKeyTable(Database db) => db.execute('''
    CREATE TABLE private_workspace_keys (
      user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      envelope TEXT NOT NULL
    )
  ''');

  Future<void> _addAccountColumns(Database db) async {
    await db.execute('ALTER TABLE users ADD COLUMN google_account_id TEXT');
    await db.execute('ALTER TABLE users ADD COLUMN google_email TEXT');
    await db.execute(
      'CREATE UNIQUE INDEX idx_users_google ON users(google_account_id)',
    );
    for (final table in ['categories', 'entries', 'media_attachments']) {
      await db.execute('ALTER TABLE $table ADD COLUMN sync_id INTEGER');
    }
  }

  Future<void> _createGuestTransfer(Database db) => db.execute('''
    CREATE TABLE guest_transfer (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      guest_id INTEGER NOT NULL REFERENCES users(id),
      target_id INTEGER NOT NULL REFERENCES users(id),
      guest_digest TEXT NOT NULL
    )
  ''');

  Future<int> migrateLegacyGoogleOwner(String googleId) async {
    final db = await database;
    return db.transaction((txn) async {
      final linked = await txn.query(
        'users',
        columns: ['id'],
        where: 'google_account_id = ?',
        whereArgs: [googleId],
      );
      if (linked.isNotEmpty) return linked.single['id'] as int;
      final original = (await txn.query(
        'users',
        orderBy: 'id',
        limit: 1,
      )).single;
      final id = original['id'] as int;
      if (original['google_account_id'] == null) {
        await txn.update(
          'users',
          {'google_account_id': googleId},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    });
  }

  Future<int> workspaceUserId() async {
    if (activeUserId case final id?) return id;
    final category = await ensureDefaultCategory();
    final db = await database;
    return (await db.query(
          'categories',
          columns: ['user_id'],
          where: 'id = ?',
          whereArgs: [category],
        )).single['user_id']
        as int;
  }
}
