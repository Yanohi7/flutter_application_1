import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/features/entry/data/datasources/entry_local_datasource.dart';
import 'package:flutter_application_1/features/entry/data/repositories/entry_repository_impl.dart';
import 'package:flutter_application_1/features/entry/domain/usecases/create_entry.dart';
import 'package:flutter_application_1/features/entry/domain/usecases/update_entry.dart';
import 'package:flutter_application_1/features/entry/domain/usecases/get_entries.dart';
import 'package:flutter_application_1/features/entry/domain/usecases/delete_entry.dart';
import 'package:flutter_application_1/features/entry/domain/entities/media_attachment.dart';
import 'package:flutter_application_1/features/entry/presentation/cubit/entry_cubit.dart';
import 'package:flutter_application_1/features/category/data/datasources/category_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late DatabaseHelper helper;
  late EntryRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    // A unique test directory; never open the actual app database.
    folder = await Directory.systemTemp.createTemp('entries-flow-test-');
    helper = DatabaseHelper.forTesting(p.join(folder.path, 'entries.db'));
    repository = EntryRepositoryImpl(EntryLocalDataSourceImpl(helper));
  });
  tearDown(() async {
    await helper.close();
    await folder.delete(
      recursive: true,
    ); // Delete only the temporary directory created above.
  });

  test(
    'Saving an attachment in reading mode preserves legacy title and text',
    () async {
      final category = await helper.ensureDefaultCategory();
      final db = await helper.database;
      const content = '  Existing text\n';
      final date = DateTime.now().toIso8601String();
      final id = await db.insert('entries', {
        'category_id': category,
        'content': content,
        'private_content': 'existing encrypted payload',
        'created_at': date,
        'updated_at': date,
      });
      final cubit = EntryCubit(
        getEntries: GetEntries(repository),
        createEntry: CreateEntry(repository),
        updateEntry: UpdateEntry(repository),
        deleteEntry: DeleteEntry(repository),
      );
      addTearDown(cubit.close);
      final original = await repository.getEntryById(id);
      final file = await File(p.join(folder.path, 'reference.txt'))
          .writeAsString('Attachment');
      final saved = await cubit.saveEntry(
        original: original,
        title: '',
        content: '',
        isPinned: false,
        isFavorite: false,
        attachmentsOnly: true,
        newAttachments: [
          MediaAttachment(
            fileType: 'document',
            fileName: 'reference.txt',
            localPath: file.path,
          ),
        ],
      );
      expect(saved, isNotNull);
      final reloaded = await repository.getEntryById(id);
      expect(reloaded.title, isNull);
      expect(reloaded.content, content);
      expect(reloaded.privateContent, original.privateContent);
      expect(reloaded.attachments.single.fileName, 'reference.txt');
    },
  );

  test(
    'The first entry persists on disk and can be read after reopening',
    () async {
      final entry = await CreateEntry(repository)(
        title: '  First entry  ',
        content: 'Sample text 🌿',
        isPinned: true,
        isFavorite: true,
      );
      expect(entry.id, isNotNull);
      final db = await helper.database;
      expect((await db.query('users')).length, 1);
      expect((await db.query('categories')).length, 1);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await helper.close(); // Simulate closing the app.
      helper = DatabaseHelper.forTesting(p.join(folder.path, 'entries.db'));
      repository = EntryRepositoryImpl(EntryLocalDataSourceImpl(helper));
      final restored = await repository.getEntryById(entry.id!);
      expect(restored.title, 'First entry');
      expect(restored.content, 'Sample text 🌿');
      expect(restored.isPinned, isTrue);
      expect(restored.isFavorite, isTrue);
      expect(restored.categoryName, 'General');
      final second = await CreateEntry(repository)(
        title: 'Second',
        content: '',
      );
      expect(
        second.categoryId,
        entry.categoryId,
      ); // Do not duplicate the guest or default category.
      expect((await (await helper.database).query('categories')).length, 1);
    },
  );

  test(
    'Reuse the existing default category without renaming or duplication',
    () async {
      final categoryId = await helper.ensureDefaultCategory();
      final db = await helper.database;
      await db.update(
        'categories',
        {'name': 'Default'},
        where: 'id = ?',
        whereArgs: [categoryId],
      );
      final entry = await CreateEntry(repository)(
        title: 'Next entry',
        content: '',
      );
      expect(entry.categoryId, categoryId);
      expect(entry.categoryName, 'Default');
      expect((await db.query('categories')).length, 1);
    },
  );

  test(
    'An empty title creates no entry; updating and permanent deletion work',
    () async {
      await expectLater(
        CreateEntry(repository)(title: '   ', content: 'Text'),
        throwsArgumentError,
      );
      expect(await repository.getEntries(), isEmpty);
      final entry = await CreateEntry(repository)(
        title: 'Title',
        content: 'Before',
      );
      await UpdateEntry(repository)(
        entry.copyWith(
          content: 'After',
          isFavorite: true,
          updatedAt: DateTime.now(),
        ),
      );
      expect((await repository.getEntryById(entry.id!)).content, 'After');
      await repository.deleteEntry(entry.id!);
      expect(await repository.getEntries(), isEmpty);
      final rows = await (await helper.database).query('entries');
      expect(rows, isEmpty);
    },
  );

  test(
    'A category read and batched attachment edit preserve filenames and labels',
    () async {
      final other = await CategoryLocalDataSource(helper)
          .createCategory(name: 'Other');
      final first = await CreateEntry(repository)(
        title: 'With attachments',
        content: '',
        attachments: [
          for (final name in ['keep.txt', 'remove.txt'])
            MediaAttachment(
              fileType: 'document',
              fileName: name,
              localPath: p.join(folder.path, name),
              displayName: name,
            ),
        ],
      );
      await CreateEntry(repository)(
        title: 'Another category',
        content: '',
        category: (id: other.id, name: other.name),
        attachments: [
          MediaAttachment(
            fileType: 'document',
            fileName: 'other.txt',
            localPath: p.join(folder.path, 'other.txt'),
          ),
        ],
      );

      // The editor may still hold the same draft objects without database IDs.
      final kept = first.attachments.first.withDisplayName('Renamed');
      await UpdateEntry(repository)(first.copyWith(attachments: [kept]));
      await UpdateEntry(repository)(first.copyWith(attachments: [kept]));
      final scoped = await repository.getEntries(categoryId: first.categoryId);
      expect(scoped.single.attachments.single.fileName, 'keep.txt');
      expect(scoped.single.attachments.single.displayName, 'Renamed');
      expect(
        (await repository.getEntries(categoryId: other.id))
            .single
            .attachments
            .single
            .fileName,
        'other.txt',
      );
    },
  );

  test(
    'Selected category persists when creating and moving an entry',
    () async {
      final categories = CategoryLocalDataSource(helper);
      final work = await categories.createCategory(name: 'Work');
      final projects = await categories.createCategory(
        name: 'Projects',
        parentId: work.id,
      );
      final entry = await CreateEntry(repository)(
        title: 'Project plan',
        content: '',
        category: (id: projects.id, name: projects.name),
      );
      final restored = await repository.getEntryById(entry.id!);
      expect(restored.categoryId, projects.id);
      expect(restored.categoryName, 'Projects');

      await UpdateEntry(repository)(
        restored.copyWith(categoryId: work.id, categoryName: work.name),
      );
      final moved = await repository.getEntryById(entry.id!);
      expect(moved.categoryId, work.id);
      expect(moved.categoryName, 'Work');
    },
  );
}
