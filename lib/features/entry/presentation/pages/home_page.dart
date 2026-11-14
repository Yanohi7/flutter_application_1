// Combine category selection, entry state, search and filters into the main entry grid
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import '../../../../core/ads/ad_banner.dart';
import '../../../../core/presentation/widgets/app_ui.dart';
import '../../../../core/presentation/app_preferences.dart';
import '../../../category/presentation/cubit/category_cubit.dart';
import '../../../category/presentation/pages/category_create_page.dart';
import '../../../category/presentation/pages/category_management_page.dart';
import '../../../category/presentation/widgets/categories_navigation.dart';
import '../../../cloud_sync/presentation/google_account_actions.dart';
import '../../../premium/presentation/pages/premium_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../domain/entities/entry.dart';
import '../cubit/entry_cubit.dart';
import '../cubit/entry_state.dart';
import '../widgets/entries_grid.dart';
import '../widgets/entry_actions.dart';
import '../widgets/entry_audio_player.dart';
import '../widgets/entry_filter_sheet.dart';
import '../widgets/entry_query.dart';
import 'entry_details_page.dart';
import 'entry_editor_page.dart';

enum _CreateAction { entry, category }

typedef _EntryQueryKey = ({
  List<Entry> source,
  String search,
  int? categoryId,
  bool globalSearch,
  bool favoritesOnly,
  String sort,
  String time,
  String content,
  DateTime? day,
});

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.isPreview = false});
  final bool isPreview;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  bool _favoritesOnly = false;
  bool _searchOpen = false;
  bool _globalSearch = false;
  EntryViewOptions _viewOptions = const EntryViewOptions();
  _EntryQueryKey? _lastQuery;
  List<Entry> _lastQueryResult = const [];
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
  // Choose between separate entry and category forms without changing existing data
  Future<void> _openCreateMenu() async {
    final action = await showModalBottomSheet<_CreateAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(AppLocalizations.of(sheetContext)!.newEntry),
              onTap: () => Navigator.pop(sheetContext, _CreateAction.entry),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(AppLocalizations.of(sheetContext)!.newCategory),
              onTap: () => Navigator.pop(sheetContext, _CreateAction.category),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _CreateAction.entry) {
      await _openEditor();
      return;
    }
    final created = await showCategoryEditor(context);
    if (!mounted || created == null) return;
    context.read<CategoryCubit>().selectCategory(created.id);
    setState(() {
      _search.clear();
      _searchOpen = false;
      _favoritesOnly = false;
      _viewOptions = const EntryViewOptions();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.categoryCreated)),
    );
  }

  Future<void> _openEditor() async {
    final saved = await Navigator.push<Entry>(
      context,
      MaterialPageRoute(builder: (_) => const EntryEditorPage()),
    );
    if (!mounted || saved == null) return;
    // Show the actual destination category returned by the editor after saving
    context.read<CategoryCubit>().selectCategory(saved.categoryId);
    setState(() {
      _search.clear();
      _searchOpen = false;
      _favoritesOnly = false;
      _viewOptions = const EntryViewOptions();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.entrySaved)),
    );
  }

  Future<void> _filters() async {
    final options = await showEntryFilters(context, _viewOptions);
    if (mounted && options != null) setState(() => _viewOptions = options);
  }

  Future<void> _changeCardSize(NoteCardSize size) async {
    if (size == appPreferences.noteCardSize) return;
    try {
      await appPreferences.setNoteCardSize(size);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.couldNotSaveTheNoteSize,
            ),
          ),
        );
      }
    }
  }

  // Explain the active view and offer a recovery action without moving entries
  Widget _emptyEntries({required int? categoryId, required bool busy}) {
    final colors = Theme.of(context).colorScheme;
    final hasFilters =
        _viewOptions.time != AppLocalizations.of(context)!.allTime ||
        _viewOptions.content != AppLocalizations.of(context)!.allTypes;
    late final IconData icon;
    late final String title;
    late final String message;
    late final String action;
    late final VoidCallback onAction;
    // Search and filters take precedence over the underlying category or favorites view
    if (_search.text.trim().isNotEmpty) {
      icon = Icons.search_off;
      title = AppLocalizations.of(context)!.noSearchResults;
      message = hasFilters
          ? AppLocalizations.of(context)!
                .noEntriesMatchYourSearchAndFiltersInThisView
          : AppLocalizations.of(context)!
                .tryADifferentTitleOrTextOrSearchInAllCategories;
      action = hasFilters
          ? AppLocalizations.of(context)!.clearSearchAndFilters
          : AppLocalizations.of(context)!.clearSearch;
      onAction = () => setState(() {
        _search.clear();
        _viewOptions = const EntryViewOptions();
      });
    } else if (hasFilters) {
      icon = Icons.filter_alt_off_outlined;
      title = AppLocalizations.of(context)!.noMatchingEntries;
      message = AppLocalizations.of(context)!
          .tryAnotherDateRangeOrContentTypeForThisView;
      action = AppLocalizations.of(context)!.resetFilters;
      onAction = () => setState(() => _viewOptions = const EntryViewOptions());
    } else if (categoryId == null && _favoritesOnly) {
      icon = Icons.star_outline;
      title = AppLocalizations.of(context)!.noFavoritesYet;
      message = AppLocalizations.of(context)!.tapTheStarOnAnEntryToKeepItHere;
      action = AppLocalizations.of(context)!.showAllEntries;
      onAction = () => setState(() => _favoritesOnly = false);
    } else {
      icon = Icons.description_outlined;
      title = categoryId != null
          ? AppLocalizations.of(context)!.thisCategoryIsEmpty
          : AppLocalizations.of(context)!.startWithYourFirstEntry;
      message = categoryId != null
          ? AppLocalizations.of(
              context,
            )!.entriesAssignedDirectlyToThisCategoryWillAppearHereSubcategoriesHaveTheirOwnEntries
          : AppLocalizations.of(context)!.captureAnIdeaAndKeepItOrganized;
      action = AppLocalizations.of(context)!.newEntry;
      onAction = _openEditor;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ReadablePanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: colors.onSurfaceVariant),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: busy ? null : onAction,
                  child: Text(action),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Entry> _visibleEntries(List<Entry> entries, int? selectedCategoryId) {
    final now = _viewOptions.time == AppLocalizations.of(context)!.allTime
        ? null
        : DateTime.now();
    final key = (
      source: entries,
      search: _search.text.trim().toLowerCase(),
      categoryId: selectedCategoryId,
      globalSearch: _globalSearch,
      favoritesOnly: _favoritesOnly,
      sort: _viewOptions.sort,
      time: _viewOptions.time,
      content: _viewOptions.content,
      day: now == null ? null : DateTime(now.year, now.month, now.day),
    );
    if (_lastQuery == key) return _lastQueryResult;
    final result = queryEntries(
      entries,
      options: _viewOptions,
      query: key.search,
      categoryId: key.categoryId,
      globalSearch: key.globalSearch,
      favoritesOnly: key.favoritesOnly,
      now: now,
    );
    _lastQuery = key;
    return _lastQueryResult = result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Subscribe this page to category changes so the entry filter follows navigation
    final categoryState = context.watch<CategoryCubit>().state;
    return BlocConsumer<EntryCubit, EntryState>(
      buildWhen: (before, after) =>
          before.status != after.status ||
          before.isSaving != after.isSaving ||
          !identical(before.entries, after.entries),
      listenWhen: (before, after) =>
          !widget.isPreview &&
          after.errorMessage != null &&
          after.errorMessage != before.errorMessage,
      listener: (context, state) {
        if (ModalRoute.of(context)?.isCurrent == true &&
            state.status != EntryStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(switch (state.errorMessage) {
                'Could not update the flag.' => AppLocalizations.of(
                  context,
                )!.couldNotUpdateFlag,
                'Could not delete the entry.' => AppLocalizations.of(
                  context,
                )!.couldNotDeleteTheEntry,
                _ => AppLocalizations.of(context)!.couldNotLoadEntries,
              }),
            ),
          );
        }
      },
      builder: (context, state) {
        final categoryId = widget.isPreview || _favoritesOnly
            ? null
            : categoryState.selectedCategoryId;
        final entries = _visibleEntries(state.entries, categoryId);
        final busy = state.isSaving || state.status == EntryStatus.loading;
        return Scaffold(
          appBar: AppBar(
            title: _favoritesOnly
                ? Text(
                    AppLocalizations.of(context)!.favorites,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            actions: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.search,
                icon: Icon(_searchOpen ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) _search.clear();
                }),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.filterSort,
                icon: Badge(
                  isLabelVisible:
                      _viewOptions.sort !=
                          AppLocalizations.of(context)!.newest ||
                      _viewOptions.time !=
                          AppLocalizations.of(context)!.allTime ||
                      _viewOptions.content !=
                          AppLocalizations.of(context)!.allTypes,
                  backgroundColor: colors.primary,
                  child: const Icon(Icons.swap_vert),
                ),
                onPressed: _filters,
              ),
              PopupMenuButton<NoteCardSize>(
                tooltip: AppLocalizations.of(context)!.noteSize,
                icon: Icon(appPreferences.noteCardSize.icon),
                onSelected: _changeCardSize,
                itemBuilder: (_) => [
                  for (final size in NoteCardSize.values)
                    CheckedPopupMenuItem(
                      value: size,
                      checked: size == appPreferences.noteCardSize,
                      child: Text(switch (size) {
                        NoteCardSize.compact => AppLocalizations.of(
                          context,
                        )!.compact,
                        NoteCardSize.standard => AppLocalizations.of(
                          context,
                        )!.standard,
                        NoteCardSize.large => AppLocalizations.of(
                          context,
                        )!.large,
                      }),
                    ),
                ],
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.profile,
                icon: const ProfileAvatar(diameter: 30),
                onPressed: () => _push(const ProfilePage()),
              ),
              const SizedBox(width: 6),
            ],
          ),
          // Keep each main destination in one place without duplicating header actions
          drawer: Drawer(
            width: 280,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                            child: Text(
                              AppLocalizations.of(context)!.yourWorkspace,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          _drawerItem(
                            AppLocalizations.of(context)!.allEntries,
                            Icons.notes_outlined,
                            () => _navigateToNotes(favorites: false),
                            selected:
                                categoryState.selectedCategoryId == null &&
                                !_favoritesOnly,
                          ),
                          _drawerItem(
                            AppLocalizations.of(context)!.favorites,
                            Icons.star_outline,
                            () => _navigateToNotes(favorites: true),
                            selected:
                                categoryState.selectedCategoryId == null &&
                                _favoritesOnly,
                          ),
                          const SizedBox(height: 12),
                          _drawerItem(
                            AppLocalizations.of(context)!.manageCategoriesLabel,
                            Icons.folder_outlined,
                            () => openCategoryManagementPage(context),
                          ),
                          _drawerItem(
                            AppLocalizations.of(context)!.settings,
                            Icons.settings_outlined,
                            () => _push(const SettingsPage()),
                          ),
                        ],
                      ),
                    ),
                    ListenableBuilder(
                      listenable: appPreferences,
                      builder: (context, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            showPremiumDialog(context);
                          },
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: Text(
                            appPreferences.isPremium
                                ? 'Premium'
                                : AppLocalizations.of(context)!.getPremium,
                          ),
                        ),
                      ),
                    ),
                    const GoogleAccountActions(),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: AppLocalizations.of(context)!.newLabel,
            clipBehavior: Clip.antiAlias,
            onPressed: busy ? null : _openCreateMenu,
            child: const Icon(Icons.add, size: 30),
          ),
          bottomNavigationBar: widget.isPreview ? null : const AdBanner(),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                    if (!widget.isPreview) const EntryMiniPlayer(),
                    if (!_favoritesOnly || _searchOpen)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).appBarTheme.backgroundColor ??
                              colors.surfaceContainer,
                          border: Border(
                            bottom: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.44,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_searchOpen) ...[
                                  TextField(
                                    controller: _search,
                                    autofocus: true,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(context)!
                                          .searchEntries,
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 20,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: AppLocalizations.of(context)!
                                            .clearSearch,
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () =>
                                            setState(_search.clear),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (!_favoritesOnly)
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        for (final global in [false, true])
                                          ChoiceChip(
                                            label: Text(
                                              global
                                                  ? AppLocalizations.of(
                                                      context,
                                                    )!.globalSearch
                                                  : AppLocalizations.of(
                                                      context,
                                                    )!.inCurrentCategory,
                                              style: TextStyle(
                                                color: _globalSearch == global
                                                    ? colors.onPrimary
                                                    : colors.onSurface,
                                              ),
                                            ),
                                            selected: _globalSearch == global,
                                            onSelected: (_) => setState(
                                              () => _globalSearch = global,
                                            ),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                ],
                                if (!_favoritesOnly)
                                  CategoriesNavigation(
                                    isPreview: widget.isPreview,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: CustomScrollView(
                        key: const PageStorageKey('entries-scroll'),
                        slivers: [
                          if (state.status == EntryStatus.loading ||
                              state.status == EntryStatus.initial)
                            const SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (state.status == EntryStatus.failure)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, size: 36),
                                    const SizedBox(height: 12),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .couldNotOpenEntries,
                                    ),
                                    TextButton(
                                      onPressed: context
                                          .read<EntryCubit>()
                                          .loadEntries,
                                      child: Text(
                                        AppLocalizations.of(context)!.tryAgain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (entries.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _emptyEntries(
                                categoryId: categoryId,
                                busy: busy,
                              ),
                            )
                          else
                            EntriesGrid(
                              entries: entries,
                              cardSize: appPreferences.noteCardSize,
                              enabled: !busy,
                              showCategoryPath:
                                  !_favoritesOnly && categoryId == null,
                              onOpen: (entry) {
                                if (entry.id != null) {
                                  _push(EntryDetailsPage(entryId: entry.id!));
                                }
                              },
                              onPin: context.read<EntryCubit>().togglePin,
                              onFavorite: context
                                  .read<EntryCubit>()
                                  .toggleFavorite,
                              onActions: (entry) =>
                                  EntryActions.show(context, entry),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToNotes({required bool favorites}) {
    context.read<CategoryCubit>().selectCategory(null);
    setState(() {
      _favoritesOnly = favorites;
      _search.clear();
      _searchOpen = false;
      _globalSearch = false;
      _viewOptions = const EntryViewOptions();
    });
  }

  Widget _drawerItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool selected = false,
  }) => ListTile(
    selected: selected,
    selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    leading: Icon(icon, size: 20),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
      onTap();
    },
  );
}
