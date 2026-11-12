// Represent entry loading, saved entries, write progress and user-facing errors

import '../../domain/entities/entry.dart';

/// Track list loading separately from database writes
enum EntryStatus { initial, loading, ready, failure }

/// The UI reads state and rebuilds; state is never modified in place
class EntryState {
  final EntryStatus status; // Indicates whether the list is ready to display
  final List<Entry> entries; // The most recently loaded list
  final bool isSaving; // Prevents repeated taps while writing
  final bool isMarking;
  final String? errorMessage; // A user-readable error message
  bool get isWriting => isSaving || isMarking;

  const EntryState({
    this.status = EntryStatus.initial,
    this.entries = const [],
    this.isSaving = false,
    this.isMarking = false,
    this.errorMessage,
  });

  // Publish a replacement snapshot and wrap replacement lists to prevent external mutation
  EntryState copyWith({
    EntryStatus? status,
    List<Entry>? entries,
    bool? isSaving,
    bool? isMarking,
    String? errorMessage,
  }) => EntryState(
    status: status ?? this.status,
    entries: entries == null ? this.entries : List.unmodifiable(entries),
    isSaving: isSaving ?? this.isSaving,
    isMarking: isMarking ?? this.isMarking,
    errorMessage:
        errorMessage, // Omitting this argument clears the previous error
  );
}
