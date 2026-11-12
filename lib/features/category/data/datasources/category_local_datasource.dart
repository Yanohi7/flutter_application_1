// Read and change SQLite categories, validate hierarchy moves and soft-delete complete branches

import 'package:sqflite/sqflite.dart';

import '../../domain/results/category_deletion_summary.dart';
import '../../../../core/database/database_helper.dart';
import '../model/category_model.dart';

class CategoryLocalDataSource {
  final DatabaseHelper dbHelper;

  CategoryLocalDataSource(this.dbHelper);

  // Start at one category and recursively collect its descendants
  // Use UNION to discard repeated IDs if the stored hierarchy contains a cycle
  static const _subtreeCte = '''
    WITH RECURSIVE subtree(id) AS (
      SELECT id
      FROM categories
      WHERE id = ? AND user_id = ? AND is_deleted = 0

      UNION

      SELECT categories.id
      FROM categories
      JOIN subtree ON categories.parent_id = subtree.id
      WHERE categories.user_id = ? AND categories.is_deleted = 0
    )
  ''';

  Future<List<CategoryModel>> getCategories() async {
    final defaultCategoryId = await dbHelper.ensureDefaultCategory();
    final db = await dbHelper.database;

    final userId = await _getUserId(db, defaultCategoryId);

    final rows = await db.query(
      'categories',
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],

      orderBy:
          'is_default DESC, sort_order  ASC, name COLLATE NOCASE ASC, id ASC',
    );

    // Convert each row map into one CategoryModel, then materialize the iterable as a list
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel> createCategory({
    required String name,
    int? parentId,
  }) async {
    final defaultCategoryId = await dbHelper.ensureDefaultCategory();
    final db = await dbHelper.database;

    // Run related reads and writes on the transaction executor so failures roll back the operation
    return db.transaction((txn) async {
      final userId = await _getUserId(txn, defaultCategoryId);

      if (parentId != null) {
        await _getCategory(
          txn,
          id: parentId,
          userId: userId,
          errorMessage: 'Parent category is not available',
        );
      }

      // SQL uses IS NULL for root categories and a bound ID for child categories
      final parentCondition = parentId == null
          ? 'parent_id IS NULL'
          : 'parent_id = ?';

      final duplicates = await txn.query(
        'categories',
        columns: ['id'],
        where:
            'user_id = ? AND $parentCondition AND name = ? AND is_deleted = 0',
        // The null-aware element adds a parent parameter only when SQL contains its placeholder
        whereArgs: [userId, ?parentId, name],
        limit: 1,
      );

      if (duplicates.isNotEmpty) {
        throw ArgumentError(
          'Category with this name already exists on this level',
        );
      }

      final now = DateTime.now().toIso8601String();

      final id = await txn.insert('categories', {
        'user_id': userId,
        'name': name,
        'parent_id': parentId,
        'created_at': now,
        'updated_at': now,
      });

      return _getCategory(txn, id: id, userId: userId);
    });
  }

  Future<CategoryModel> updateCategory({
    required int id,
    required String name,
    required int? parentId,
  }) async {
    final defaultCategoryId = await dbHelper.ensureDefaultCategory();
    final db = await dbHelper.database;

    // Run related reads and writes on the transaction executor so failures roll back the operation
    return db.transaction((txn) async {
      final userId = await _getUserId(txn, defaultCategoryId);

      final current = await _getCategory(txn, id: id, userId: userId);

      if (current.isDefault && parentId != null) {
        throw ArgumentError(
          "Default category can't be moved to another category!",
        );
      }

      // Walk upward from the proposed parent and reject moving a category below itself
      final visited = <int>{id};

      int? currentParentId = parentId;

      while (currentParentId != null) {
        if (visited.contains(currentParentId)) {
          throw ArgumentError(
            "Category can't be moved to itself or to its own subcategory!",
          );
        }

        visited.add(currentParentId);

        final parent = await _getCategory(
          txn,
          id: currentParentId,
          userId: userId,
          errorMessage: 'Parent category is not available',
        );

        currentParentId = parent.parentId;
      }

      // SQL uses IS NULL for root categories and a bound ID for child categories
      final parentCondition = parentId == null
          ? 'parent_id IS NULL'
          : 'parent_id = ?';

      final duplicates = await txn.query(
        'categories',
        columns: ['id'],
        where:
            'user_id = ? AND $parentCondition AND name = ? '
            'AND id != ? AND is_deleted = 0',
        // The null-aware element adds a parent parameter only when SQL contains its placeholder
        whereArgs: [userId, ?parentId, name, id],
        limit: 1,
      );

      if (duplicates.isNotEmpty) {
        throw ArgumentError('Category with this name already exists');
      }

      final count = await txn.update(
        'categories',
        {
          'name': name,
          'parent_id': parentId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND user_id = ? AND is_deleted = 0',
        whereArgs: [id, userId],
      );

      if (count != 1) {
        throw StateError('Failed to update the category');
      }

      return _getCategory(txn, id: id, userId: userId);
    });
  }

  Future<CategoryDeletionSummary> getDeletionSummary(int id) async {
    final defaultCategoryId = await dbHelper.ensureDefaultCategory();
    final db = await dbHelper.database;

    // Run related reads and writes on the transaction executor so failures roll back the operation
    return db.transaction((txn) async {
      final userId = await _getUserId(txn, defaultCategoryId);
      final category = await _getCategory(txn, id: id, userId: userId);

      if (category.isDefault) {
        throw ArgumentError('Default category cannot be deleted.');
      }

      final rows = await txn.rawQuery(
        '''
        $_subtreeCte

        SELECT
          (SELECT COUNT(*) FROM subtree) AS category_count,

          (
          SELECT COUNT(*)
          FROM entries
          WHERE is_deleted = 0
            AND category_id IN (SELECT id FROM subtree)
          ) AS entry_count
        ''',
        [id, userId, userId],
      );

      final counts = rows.single;
      final categoryCount = counts['category_count'] as int;

      return CategoryDeletionSummary(
        categoryId: id,
        // Exclude the selected category itself from the number of descendants
        descendantCategoryCount: categoryCount - 1,

        entryCount: counts['entry_count'] as int,
      );
    });
  }

  Future<void> deleteCategory(int id) async {
    final defaultCategoryId = await dbHelper.ensureDefaultCategory();
    final db = await dbHelper.database;

    // Soft-delete attachments, entries and categories together to avoid a partly deleted branch
    await db.transaction((txn) async {
      final userId = await _getUserId(txn, defaultCategoryId);
      final category = await _getCategory(txn, id: id, userId: userId);

      if (category.isDefault) {
        throw ArgumentError('Default category cannot be deleted');
      }

      final now = DateTime.now().toIso8601String();

      await txn.rawUpdate(
        '''
        $_subtreeCte

        UPDATE media_attachments
        SET is_deleted = 1, deleted_at = ?
        WHERE is_deleted = 0
          AND entry_id IN (
          SELECT id 
          FROM entries
          WHERE category_id IN (SELECT id FROM subtree)
          )
        ''',
        [id, userId, userId, now],
      );

      await txn.rawUpdate(
        '''
        $_subtreeCte

        UPDATE entries
        SET is_deleted = 1, deleted_at = ?, updated_at = ?
        WHERE is_deleted = 0
          AND category_id IN (SELECT id FROM subtree)
        ''',
        [id, userId, userId, now, now],
      );

      await txn.rawUpdate(
        '''
        $_subtreeCte

        UPDATE categories
        SET is_deleted = 1, deleted_at = ?, updated_at = ?
        WHERE is_deleted = 0
          AND id IN (SELECT id FROM subtree)
        ''',
        [id, userId, userId, now, now],
      );
    });
  }

  // Read the local owner through either a database or a transaction executor
  Future<int> _getUserId(
    DatabaseExecutor executor,
    int defaultCategoryId,
  ) async {
    final rows = await executor.query(
      'categories',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [defaultCategoryId],
      limit: 1,
    );

    return rows.single['user_id'] as int;
  }

  // Require an active category owned by the same user before continuing an operation
  Future<CategoryModel> _getCategory(
    DatabaseExecutor executor, {
    required int id,
    required int userId,
    String errorMessage = 'Category is not available',
  }) async {
    final rows = await executor.query(
      'categories',
      where: 'id = ? AND user_id = ? AND is_deleted = 0',
      whereArgs: [id, userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw ArgumentError(errorMessage);
    }

    return CategoryModel.fromMap(rows.single);
  }
}
