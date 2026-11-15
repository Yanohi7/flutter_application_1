// Select a category from a searchable expandable tree and distinguish cancellation from top level
import 'dart:math' as math;

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/features/category/presentation/category_display_name.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../domain/entities/entry_category.dart';

// A null dialog result means cancellation; a null category means top level
class CategorySelection {
  final EntryCategory? category;
  const CategorySelection(this.category);
  int? get id => category?.id;
}

Future<CategorySelection?> showCategoryPicker({
  required BuildContext context,
  required List<EntryCategory> categories,
  int? selectedId,
  bool allowTopLevel = false,
  String? title,
  Future<EntryCategory?> Function(BuildContext context)? onCreateCategory,
}) {
  return showAppDialog<CategorySelection>(
    context: context,
    builder: (_) => _CategoryPicker(
      categories: List.unmodifiable(categories),
      selectedId: selectedId,
      allowTopLevel: allowTopLevel,
      title: title ?? AppLocalizations.of(context)!.chooseCategory,
      onCreateCategory: onCreateCategory,
    ),
  );
}

class _CategoryPicker extends StatefulWidget {
  final List<EntryCategory> categories;
  final int? selectedId;
  final bool allowTopLevel;
  final String title;
  final Future<EntryCategory?> Function(BuildContext context)? onCreateCategory;
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.allowTopLevel,
    required this.title,
    required this.onCreateCategory,
  });
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

typedef _CategoryRow = ({EntryCategory category, int depth, bool hasChildren});

class _CategoryPickerState extends State<_CategoryPicker> {
  bool _creating = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _expanded = <int>{};
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(EntryCategory? category) {
    Navigator.of(context).pop(CategorySelection(category));
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreateCategory!(context);
      if (mounted && created != null) _select(created);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _search.text.trim().toLowerCase();
    final byId = {for (final c in widget.categories) c.id: c};
    // Group rows by parent ID so the tree can be rendered one level at a time
    final children = <int?, List<EntryCategory>>{};
    for (final category in widget.categories) {
      final parent = byId.containsKey(category.parentId)
          ? category.parentId
          : null;
      children.putIfAbsent(parent, () => []).add(category);
    }
    // Search reveals matching nodes with their ancestors, without changing
    // The user's collapsed/expanded choices when the search is cleared
    final included = <int>{};
    if (query.isNotEmpty) {
      for (final category in widget.categories) {
        if (!category.name.toLowerCase().contains(query) &&
            !l10n
                .categoryDisplayName(category.name)
                .toLowerCase()
                .contains(query)) {
          continue;
        }
        EntryCategory? current = category;
        final visited = <int>{};
        while (current != null && visited.add(current.id)) {
          included.add(current.id);
          current = byId[current.parentId];
        }
      }
    }
    final rows = <_CategoryRow>[];
    final visited = <int>{};
    // Flatten visible tree nodes into rows with indentation and guard against repeated IDs
    void append(EntryCategory category, int depth) {
      if (!visited.add(category.id)) return;
      if (query.isNotEmpty && !included.contains(category.id)) return;
      final descendants = children[category.id] ?? const <EntryCategory>[];
      final hasChildren = descendants.any(
        (child) => query.isEmpty || included.contains(child.id),
      );
      rows.add((category: category, depth: depth, hasChildren: hasChildren));
      if (query.isNotEmpty || _expanded.contains(category.id)) {
        for (final child in descendants) {
          append(child, depth + 1);
        }
      }
    }

    for (final root in children[null] ?? const <EntryCategory>[]) {
      append(root, 0);
    }
    final topLevel = widget.allowTopLevel && query.isEmpty;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(widget.title),
                trailing: IconButton(
                  tooltip: AppLocalizations.of(context)!.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchCategories,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: AppLocalizations.of(context)!
                                .clearCategorySearch,
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (widget.onCreateCategory != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _creating ? null : _create,
                      icon: const Icon(Icons.add),
                      label: Text(
                        AppLocalizations.of(context)!.createNewCategory,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: rows.isEmpty && !topLevel
                    ? Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          AppLocalizations.of(context)!.noCategoriesFound,
                        ),
                      )
                    : _categoryTree(
                        rows,
                        topLevel: topLevel,
                        searching: query.isNotEmpty,
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static const _indent = 16.0;
  static const _leftPadding = 12.0;
  static const _rightPadding = 8.0;
  static const _iconWidth = 40.0;
  static const _gap = 8.0;

  Widget _categoryTree(
    List<_CategoryRow> rows, {
    required bool topLevel,
    required bool searching,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final painter = TextPainter(
      text: TextSpan(
        text: l10n.select,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    )..layout();
    final selectWidth = math.max(80.0, painter.width.ceilToDouble() + 16);
    painter.dispose();

    final behavior = ScrollConfiguration.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ScrollConfiguration(
        behavior: behavior.copyWith(
          scrollbars: false,
          dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
        ),
        child: Scrollbar(
          controller: _scroll,
          child: ListView.builder(
            controller: _scroll,
            shrinkWrap: true,
            itemCount: rows.length + (topLevel ? 1 : 0),
            itemBuilder: (context, index) {
              if (topLevel && index == 0) {
                return ListTile(
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: _leftPadding,
                    end: _rightPadding,
                  ),
                  title: _categoryTitle(l10n.noneTopLevel),
                  selected: widget.selectedId == null,
                  onTap: () => _select(null),
                );
              }
              final row = rows[index - (topLevel ? 1 : 0)];
              return _categoryTile(
                row,
                searching: searching,
                selectWidth: math.min(selectWidth, constraints.maxWidth * 0.4),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _categoryTitle(String text, {int depth = 0, Widget? icon}) =>
      SingleChildScrollView(
        primary: false,
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: depth * _indent),
            SizedBox(width: _iconWidth, child: icon),
            const SizedBox(width: _gap),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Text(text, maxLines: 1, softWrap: false),
            ),
          ],
        ),
      );

  Widget _categoryTile(
    _CategoryRow row, {
    required bool searching,
    required double selectWidth,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final category = row.category;
    final expanded = searching || _expanded.contains(category.id);
    void toggle() {
      setState(() {
        if (!_expanded.remove(category.id)) _expanded.add(category.id);
      });
    }

    return ListTile(
      key: ValueKey('category-option-${category.id}'),
      contentPadding: const EdgeInsetsDirectional.only(
        start: _leftPadding,
        end: _rightPadding,
      ),
      horizontalTitleGap: _gap,
      selected: category.id == widget.selectedId,
      title: _categoryTitle(
        l10n.categoryDisplayName(category.name),
        depth: row.depth,
        icon: row.hasChildren
            ? IconButton(
                tooltip: expanded ? l10n.collapse : l10n.expand,
                onPressed: searching ? null : toggle,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              )
            : const Icon(Icons.folder_outlined),
      ),
      onTap: row.hasChildren
          ? (searching ? null : toggle)
          : () => _select(category),
      trailing: SizedBox(
        width: selectWidth,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => _select(category),
          child: Text(l10n.select, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
