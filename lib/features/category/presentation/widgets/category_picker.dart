// Select a category from a searchable expandable tree and distinguish cancellation from top level

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
  String title = 'Choose category',
  Future<EntryCategory?> Function(BuildContext context)? onCreateCategory,
}) {
  return showAppDialog<CategorySelection>(
    context: context,
    builder: (_) => _CategoryPicker(
      categories: List.unmodifiable(categories),
      selectedId: selectedId,
      allowTopLevel: allowTopLevel,
      title: title,
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
        if (!category.name.toLowerCase().contains(query)) continue;
        EntryCategory? current = category;
        final visited = <int>{};
        while (current != null && visited.add(current.id)) {
          included.add(current.id);
          current = byId[current.parentId];
        }
      }
    }

    final rows = <({EntryCategory category, int depth, bool hasChildren})>[];
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
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search categories',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear category search',
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
                      label: const Text('Create New Category'),
                    ),
                  ),
                ),
              Flexible(
                child: rows.isEmpty && !topLevel
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No categories found'),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          itemCount: rows.length + (topLevel ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (topLevel && index == 0) {
                              return ListTile(
                                title: const Text('None (top level)'),
                                selected: widget.selectedId == null,
                                onTap: () => _select(null),
                              );
                            }
                            // Offset the data index when the optional top-level choice occupies the first row
                            final row = rows[index - (topLevel ? 1 : 0)];
                            final category = row.category;
                            final expanded =
                                query.isNotEmpty ||
                                _expanded.contains(category.id);
                            void toggle() {
                              if (query.isNotEmpty) return;
                              setState(() {
                                if (!_expanded.remove(category.id)) {
                                  _expanded.add(category.id);
                                }
                              });
                            }

                            return ListTile(
                              key: ValueKey('category-option-${category.id}'),
                              contentPadding: EdgeInsets.only(
                                left: 16 + row.depth.clamp(0, 6) * 16.0,
                                right: 8,
                              ),
                              selected: category.id == widget.selectedId,
                              leading: row.hasChildren
                                  ? IconButton(
                                      tooltip: expanded
                                          ? 'Collapse ${category.name}'
                                          : 'Expand ${category.name}',
                                      onPressed: query.isEmpty ? toggle : null,
                                      icon: Icon(
                                        expanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                      ),
                                    )
                                  : const Icon(Icons.folder_outlined),
                              title: Text(category.name),
                              // Parent rows expand; their Select button picks
                              // The parent itself. Leaf rows select directly
                              onTap: row.hasChildren
                                  ? toggle
                                  : () => _select(category),
                              trailing: TextButton(
                                onPressed: () => _select(category),
                                child: const Text('Select'),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
