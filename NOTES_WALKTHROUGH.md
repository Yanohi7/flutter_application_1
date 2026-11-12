# How the first note works

The project has a home page, an adaptive grid, and a form for creating and editing text notes. Data is stored locally in SQLite. The Clean Architecture and feature-first structure is preserved: changes stay within the existing entry feature, app, and core layers.

## Try it yourself

1. Run the app on Android or Windows. After dependency changes, restart the app fully rather than only using hot reload.
2. Tap New note.
3. Enter a title. You can add the text now or later. Optionally enable Pin or Add to favorites.
4. Tap Save note. A card appears on the home page.
5. Tap the card to read the full text and edit it.
6. Close and reopen the app: the note remains in the SQLite file.

Search matches titles and text. Favorites filters the same notes. Pinned cards always appear first. The menu lets you delete an entry after confirmation.

## Recommended reading order

1. [lib/main.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/main.dart) — starts Flutter and selects SQLite FFI on Windows/Linux.
2. [lib/app/app.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/app/app.dart) — assembles DatabaseHelper, datasource, repository, use cases, and Cubit. This is the composition root where data connects to domain; the UI does not create repositories itself.
3. [lib/features/entry/presentation/pages/home_page.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/pages/home_page.dart) — reads EntryState through BlocConsumer, opens the editor, and holds local filters.
4. [lib/features/entry/presentation/widgets/entries_grid.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/widgets/entries_grid.dart) → [lib/features/entry/presentation/widgets/entry_card.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/widgets/entry_card.dart) — read the grid layout first, then an individual card.
5. [lib/features/entry/presentation/pages/entry_editor_page.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/pages/entry_editor_page.dart) — text controllers, Form, title validation, unsaved-change protection, and the _save() method.
6. [lib/features/entry/presentation/cubit/entry_cubit.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/cubit/entry_cubit.dart) and [lib/features/entry/presentation/cubit/entry_state.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/cubit/entry_state.dart) — loading and saving state, use case calls, and list updates.
7. [lib/features/entry/domain/usecases/create_entry.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/usecases/create_entry.dart) — nonempty title validation, category resolution, timestamps, and Entry creation. The get_entries, update_entry, and delete_entry use cases are alongside it.
8. [lib/features/entry/domain/entities/entry.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/entities/entry.dart) and [lib/features/entry/domain/repositories/entries_repository.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/repositories/entries_repository.dart) — pure data and the contract, with no Flutter or SQLite imports.
9. [lib/features/entry/data/repositories/entry_repository_impl.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/data/repositories/entry_repository_impl.dart) — implements the contract through the datasource.
10. [lib/features/entry/data/model/entry_model.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/data/model/entry_model.dart) — converts Entry to and from Map. Booleans become 0/1, and DateTime values become ISO strings.
11. [lib/features/entry/data/datasources/entry_local_datasource.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/data/datasources/entry_local_datasource.dart) — SQL queries for reading, inserting, updating, and soft deletion.
12. [lib/core/database/database_helper.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/core/database/database_helper.dart) — the connection, tables, and the transaction that prepares the guest profile and default category.

## What happens when Save is tapped

```text
EntryEditorPage._save()
  → Form.validate()
  → EntryCubit.saveEntry()
  → CreateEntry.call()
  → EntriesRepository.getDefaultCategory()
  → EntryRepositoryImpl → EntryLocalDataSourceImpl
  → DatabaseHelper.ensureDefaultCategory()
  → EntriesRepository.createEntry()
  → EntryModel.fromEntity() → toMap() → SQLite INSERT
  ← the new entry ID
  ← Entry with that ID
  → EntryCubit._putEntry() → emit(EntryState)
  → the editor returns true through Navigator.pop()
  → HomePage displays the updated grid
```

The arrows show execution flow. Code dependencies in Clean Architecture point toward domain: presentation and data know the EntriesRepository contract, while domain does not know their implementations.

## Why the grid works this way

- HomePage has one CustomScrollView. The header, search field, and cards scroll together.
- EntriesGrid returns a SliverGrid, so there is no nested GridView with its own scrolling.
- SliverLayoutBuilder uses the actual available width to choose 1 to 4 columns. A 390 px viewport usually has 2 columns.
- Larger system text increases the minimum card width and card height.
- Titles and previews have line limits. Entry retains the complete text.
- Bottom padding lets the last card scroll above the create button.

## How data is protected

- Save waits for SQLite INSERT/UPDATE to complete. Repeated taps are disabled while writing.
- A save failure leaves text in TextEditingController.
- Leaving a form with unsaved changes requires confirmation.
- The table schema and existing test_database.db filename are preserved. The guest profile and category are created only when needed.
- An existing default category is reused with its own name. A fresh database creates General.
- Tests use a separate in-memory database or temporary file. The original database test no longer deletes the app data file.
- Deletion sets is_deleted = 1. A restore screen is not implemented yet.

## Scope of this stage

Text notes use the default category. Category management, media, structured content, ads, profiles, Premium, and synchronization remain for later stages. Their empty placeholder files are preserved.

The light/dark switch applies to the current session; persisting theme settings is not implemented yet. SQLite is configured for mobile platforms and Windows/Linux; Chrome web storage is not implemented in this stage. The local learning scenario uses the first profile in the users table; account switching is not implemented yet.

## Verification

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The Android debug build was also checked with `flutter build apk --debug`. Widget tests cover creating and editing, failures, repeated taps, unsaved changes, search, favorites, deletion, widths of 320/390/768/1200, larger text, and the keyboard. SQLite tests check reopening a file, table relationships, and reusing an existing category.

[flutter_bloc](https://pub.dev/packages/flutter_bloc) connects the existing Cubit to the UI. The earlier HomePage and EntryEditorPage learning examples were replaced with the working note flow.

## Complete file list


New files:

- [NOTES_WALKTHROUGH.md](C:/Users/vikto/Documents/practice/flutter_application_1/NOTES_WALKTHROUGH.md)
- [test/features/entry/entry_persistence_test.dart](C:/Users/vikto/Documents/practice/flutter_application_1/test/features/entry/entry_persistence_test.dart)
- [test/support/test_entries_repository.dart](C:/Users/vikto/Documents/practice/flutter_application_1/test/support/test_entries_repository.dart)

Changed files, including previously empty placeholders:

- [lib/app/app.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/app/app.dart)
- [lib/core/database/database_helper.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/core/database/database_helper.dart)
- [lib/core/theme/app_colors.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/core/theme/app_colors.dart)
- [lib/core/theme/app_theme.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/core/theme/app_theme.dart)
- [lib/core/utils/datetime_helpers.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/core/utils/datetime_helpers.dart)
- [lib/features/entry/data/datasources/entry_local_datasource.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/data/datasources/entry_local_datasource.dart)
- [lib/features/entry/data/model/entry_model.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/data/model/entry_model.dart)
- [lib/features/entry/data/repositories/entry_repository_impl.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/data/repositories/entry_repository_impl.dart)
- [lib/features/entry/domain/entities/entry.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/entities/entry.dart)
- [lib/features/entry/domain/entities/media_attachment.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/entities/media_attachment.dart)
- [lib/features/entry/domain/repositories/entries_repository.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/repositories/entries_repository.dart)
- [lib/features/entry/domain/usecases/create_entry.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/usecases/create_entry.dart)
- [lib/features/entry/domain/usecases/delete_entry.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/usecases/delete_entry.dart)
- [lib/features/entry/domain/usecases/get_entries.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/usecases/get_entries.dart)
- [lib/features/entry/domain/usecases/update_entry.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/domain/usecases/update_entry.dart)
- [lib/features/entry/presentation/cubit/entry_cubit.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/cubit/entry_cubit.dart)
- [lib/features/entry/presentation/cubit/entry_state.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/cubit/entry_state.dart)
- [lib/features/entry/presentation/pages/entry_editor_page.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/pages/entry_editor_page.dart)
- [lib/features/entry/presentation/pages/home_page.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/pages/home_page.dart)
- [lib/features/entry/presentation/pages/notifiers.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/pages/notifiers.dart)
- [lib/features/entry/presentation/widgets/entries_grid.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/widgets/entries_grid.dart)
- [lib/features/entry/presentation/widgets/entry_card.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/entry/presentation/widgets/entry_card.dart)
- [lib/features/category/presentation/widgets/categories_navigation.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/features/category/presentation/widgets/categories_navigation.dart)
- [lib/main.dart](C:/Users/vikto/Documents/practice/flutter_application_1/lib/main.dart)
- [pubspec.lock](C:/Users/vikto/Documents/practice/flutter_application_1/pubspec.lock)
- [pubspec.yaml](C:/Users/vikto/Documents/practice/flutter_application_1/pubspec.yaml)
- [test/core/database/database_helper_test.dart](C:/Users/vikto/Documents/practice/flutter_application_1/test/core/database/database_helper_test.dart)
- [test/widget_test.dart](C:/Users/vikto/Documents/practice/flutter_application_1/test/widget_test.dart)

Files and folders were not moved. Initial source snapshots and review screenshots are stored in .dart_tool/notes_review and are not needed to run the app.
