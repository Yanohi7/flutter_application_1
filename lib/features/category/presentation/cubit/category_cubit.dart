// Run category use cases and publish loading, selection, saving and error states to widgets

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entry_category.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/create_category.dart';
import '../../domain/usecases/update_category.dart';
import '../../domain/usecases/get_category_deletion_summary.dart';
import '../../domain/usecases/delete_category.dart';
import '../../domain/results/category_deletion_summary.dart';
import 'category_state.dart';

class CategoryCubit extends Cubit<CategoryState> {
  final GetCategories _getCategories;
  final CreateCategory _createCategory;
  final UpdateCategory _updateCategory;
  final GetCategoryDeletionSummary _getCategoryDeletionSummary;
  final DeleteCategory _deleteCategory;

  CategoryCubit({
    required GetCategories getCategories,
    required CreateCategory createCategory,
    required UpdateCategory updateCategory,
    required GetCategoryDeletionSummary getCategoryDeletionSummary,
    required DeleteCategory deleteCategory,
  }) : _getCategories = getCategories,
       _createCategory = createCategory,
       _updateCategory = updateCategory,
       _getCategoryDeletionSummary = getCategoryDeletionSummary,
       _deleteCategory = deleteCategory,
       super(CategoryState());

  // Load through the use case and publish a new state that subscribed widgets can rebuild from
  Future<void> loadCategories() async {
    if (isClosed || state.status == CategoryStatus.loading || state.isSaving) {
      return;
    }

    emit(state.copyWith(status: CategoryStatus.loading, clearError: true));
    try {
      final categories = await _getCategories();

      if (isClosed) return;

      final selectedId = state.selectedCategoryId;

      // Clear a selection only when its category disappeared from the refreshed list
      final selectionExists =
          selectedId == null ||
          categories.any((category) => category.id == selectedId);

      emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: categories,
          clearSelection: !selectionExists,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: "Failed to load categories. Please try again",
        ),
      );
    }
  }

  // Change navigation state without moving entries or changing their stored category
  void selectCategory(int? id) {
    if (isClosed || state.status != CategoryStatus.success || state.isSaving) {
      return;
    }

    if (id != null && !state.categories.any((category) => category.id == id)) {
      return;
    }

    emit(state.copyWith(selectedCategoryId: id, clearSelection: id == null));
  }

  // Return the saved category so the calling page can navigate to its generated ID
  Future<EntryCategory?> createCategory({
    required String name,
    int? parentId,
  }) async {
    if (isClosed || state.isSaving || state.status != CategoryStatus.success) {
      return null;
    }

    emit(state.copyWith(isSaving: true, clearError: true));
    final EntryCategory created;
    try {
      created = await _createCategory(name: name, parentId: parentId);
    } catch (error) {
      if (isClosed) return null;

      final message = error is ArgumentError
          ? error.message.toString()
          : 'Failed to create category. Please try again.';

      emit(state.copyWith(isSaving: false, errorMessage: message));

      return null;
    }

    if (isClosed) return created;

    emit(state.copyWith(isSaving: false));

    // Refresh the list after writing so names, parents and deleted branches match storage
    await loadCategories();

    return created;
  }

  // Change the name and parent of an existing category
  Future<bool> updateCategory({
    required int id,
    required String name,
    required int? parentId,
  }) async {
    // Require the loaded list before starting a write
    // Reject the operation while another write is in progress
    if (isClosed || state.isSaving || state.status != CategoryStatus.success) {
      return false;
    }

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      await _updateCategory(id: id, name: name, parentId: parentId);
    } catch (error) {
      if (isClosed) return false;

      final message = error is ArgumentError
          ? error.message.toString()
          : 'Failed to update category. Please try again.';

      emit(state.copyWith(isSaving: false, errorMessage: message));

      return false;
    }

    if (isClosed) return true;

    emit(state.copyWith(isSaving: false));

    // Refresh the list after writing so names, parents and deleted branches match storage
    await loadCategories();

    return true;
  }

  // Fetch confirmation counts without deleting data or changing category selection
  Future<CategoryDeletionSummary?> getDeletionSummary(int id) async {
    if (isClosed || state.isSaving || state.status != CategoryStatus.success) {
      return null;
    }

    emit(state.copyWith(clearError: true));

    try {
      final summary = await _getCategoryDeletionSummary(id: id);

      if (isClosed) return null;

      return summary;
    } catch (error) {
      if (isClosed) return null;

      final message = error is ArgumentError
          ? error.message.toString()
          : 'Failed to calculate deletion details. Please try again.';

      emit(state.copyWith(errorMessage: message));

      return null;
    }
  }

  // Report success separately from list loading so the confirmation page knows when to close
  Future<bool> deleteCategory(int id) async {
    if (isClosed || state.isSaving || state.status != CategoryStatus.success) {
      return false;
    }

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      await _deleteCategory(id: id);
    } catch (error) {
      if (isClosed) return false;

      final message = error is ArgumentError
          ? error.message.toString()
          : 'Failed to delete category. Please try again.';

      emit(state.copyWith(isSaving: false, errorMessage: message));

      return false;
    }

    if (isClosed) return true;

    emit(state.copyWith(isSaving: false));

    // Refresh the list after writing so names, parents and deleted branches match storage
    await loadCategories();

    return true;
  }
}
