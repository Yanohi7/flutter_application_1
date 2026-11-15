// Coordinate entry use cases and update the in-memory list consumed by entry widgets

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entry.dart';
import '../../domain/entities/media_attachment.dart';
import '../../domain/usecases/create_entry.dart';
import '../../domain/usecases/delete_entry.dart';
import '../../domain/usecases/get_entries.dart';
import '../../domain/usecases/update_entry.dart';
import 'entry_state.dart';

/// Connect pages to the domain layer without SQL or BuildContext
class EntryCubit extends Cubit<EntryState> {
  final GetEntries getEntries;
  final CreateEntry createEntry;
  final UpdateEntry updateEntry;
  final DeleteEntry deleteEntry;

  EntryCubit({
    required this.getEntries,
    required this.createEntry,
    required this.updateEntry,
    required this.deleteEntry,
  }) : super(const EntryState());

  Future<void>? _loadingEntries;

  Future<void> loadEntries({bool refreshAfterCurrent = false}) async {
    if (isClosed || state.isWriting) return;
    if (_loadingEntries case final pending?) {
      await pending;
      if (refreshAfterCurrent) await loadEntries();
      return;
    }
    final pending = _readEntries();
    _loadingEntries = pending;
    try {
      await pending;
    } finally {
      _loadingEntries = null;
    }
  }

  Future<void> _readEntries() async {
    emit(state.copyWith(status: EntryStatus.loading));
    try {
      final entries =
          await getEntries(); // Call the use case rather than the datasource
      if (isClosed) return; // The page or app may already have been closed
      emit(state.copyWith(status: EntryStatus.ready, entries: entries));
    } catch (error, stackTrace) {
      addError(
        error,
        stackTrace,
      ); // BlocObserver can receive the technical error details
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EntryStatus.failure,
          errorMessage: 'Could not load entries. Please try again.',
        ),
      );
    }
  }

  /// Use the same form method for creating and editing
  Future<Entry?> saveEntry({
    Entry? original,
    required String title,
    required String content,
    String? privateContent,
    required bool isPinned,
    required bool isFavorite,
    List<MediaAttachment> newAttachments = const [],
    List<MediaAttachment>? retainedAttachments,
    ({int id, String name})? category,
    bool attachmentsOnly = false,
    bool checklistOnly = false,
  }) async {
    if (isClosed || state.isWriting || state.status == EntryStatus.loading) {
      return null;
    }
    emit(state.copyWith(isSaving: true)); // Disable repeated saves
    try {
      final Entry saved;
      if (original == null) {
        saved = await createEntry(
          title: title,
          content: content,
          privateContent: privateContent ?? '',
          isPinned: isPinned,
          isFavorite: isFavorite,
          category: category,
          attachments: newAttachments,
        );
      } else {
        final attachments = [
          ...(retainedAttachments ?? original.attachments),
          ...newAttachments,
        ];
        saved = checklistOnly
            ? original.copyWith(content: content, updatedAt: DateTime.now())
            : attachmentsOnly
            ? original.copyWith(
                attachments: attachments,
                updatedAt: DateTime.now(),
              )
            : original.copyWith(
                title: title.trim(),
                content: content.trim(),
                privateContent: privateContent,
                isPinned: isPinned,
                isFavorite: isFavorite,
                updatedAt: DateTime.now(),
                categoryId: category?.id,
                categoryName: category?.name,
                attachments: attachments,
              );
        await updateEntry(
          saved,
          allowUntitled: attachmentsOnly || checklistOnly,
        );
      }
      if (isClosed) return saved;
      _putEntry(saved); // Update the list without another query after INSERT
      return saved; // Return the actual saved category and generated ID
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage:
                'Could not save the entry. Your text is still in the form.',
          ),
        );
      }
      return null;
    }
  }

  // Merge the saved entry by ID and publish the ordered list only after a successful write
  void _putEntry(Entry saved) {
    // Replace an entry when editing or add one when creating
    final entries = [...state.entries.where((e) => e.id != saved.id), saved];
    entries.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final byDate = b.updatedAt.compareTo(a.updatedAt);
      return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    emit(
      state.copyWith(
        entries: entries,
        status: EntryStatus.ready,
        isSaving: false,
        isMarking: false,
      ),
    );
  }

  Future<void> togglePin(Entry entry) => _changeMark(entry.id, favorite: false);

  Future<void> toggleFavorite(Entry entry) =>
      _changeMark(entry.id, favorite: true);

  Future<void> _changeMark(int? id, {required bool favorite}) async {
    if (isClosed ||
        id == null ||
        state.isWriting ||
        state.status != EntryStatus.ready) {
      return;
    }
    final current = state.entries.where((entry) => entry.id == id).firstOrNull;
    if (current == null) return;
    final pinned = favorite ? null : !current.isPinned;
    final starred = favorite ? !current.isFavorite : null;
    emit(state.copyWith(isMarking: true));
    try {
      await updateEntry.flags(id, pinned: pinned, favorite: starred);
      if (!isClosed) {
        _putEntry(current.copyWith(isPinned: pinned, isFavorite: starred));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            isMarking: false,
            errorMessage: 'Could not update the flag.',
          ),
        );
      }
    }
  }

  // Remove the visible entry only after the repository confirms deletion
  Future<bool> removeEntry(Entry entry) async {
    if (isClosed ||
        state.isWriting ||
        state.status != EntryStatus.ready ||
        entry.id == null) {
      return false;
    }
    emit(state.copyWith(isSaving: true));
    try {
      await deleteEntry(
        entry.id!,
      ); // The UI has already received user confirmation
      if (!isClosed) {
        emit(
          state.copyWith(
            entries: state.entries.where((e) => e.id != entry.id).toList(),
            isSaving: false,
          ),
        );
      }
      return true;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: 'Could not delete the entry.',
          ),
        );
      }
      return false;
    }
  }
}
