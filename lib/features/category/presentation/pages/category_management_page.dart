// Display an expandable category tree with create, rename, move and delete actions

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../entry/presentation/cubit/entry_cubit.dart';
import '../../domain/entities/entry_category.dart';
import '../cubit/category_cubit.dart';
import '../cubit/category_state.dart';
import 'category_create_page.dart';
import 'category_delete_page.dart';
import '../widgets/category_actions.dart';

Future<void> openCategoryManagementPage(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CategoryCubit>()),
            BlocProvider.value(value: context.read<EntryCubit>()),
          ],
          child: const CategoryManagementPage(),
        ),
      ),
    );

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});
  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _expanded = <int>{};

  // Refresh entries after category edits because their displayed category names may have changed
  Future<void> _form({EntryCategory? category, int? parentId}) async {
    final saved = await showCategoryEditor(
      context,
      category: category,
      initialParentId: parentId,
    );
    if (!mounted || saved == null) return;
    await context.read<EntryCubit>().loadEntries();
    if (mounted && parentId != null) setState(() => _expanded.add(parentId));
  }

  // Reload entries after a successful cascade so deleted cards disappear from the home list
  Future<void> _delete(EntryCategory category) async {
    final deleted = await showCategoryDeleteDialog(context, category);
    if (mounted && deleted == true)
      await context.read<EntryCubit>().loadEntries();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context)!.manageCategories)),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: BlocBuilder<CategoryCubit, CategoryState>(
            builder: (context, state) {
              if (state.status == CategoryStatus.loading ||
                  state.status == CategoryStatus.initial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == CategoryStatus.failure) {
                return Center(
                  child: OutlinedButton.icon(
                    onPressed: context.read<CategoryCubit>().loadCategories,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      AppLocalizations.of(context)!.retryLoadingCategories,
                    ),
                  ),
                );
              }
              // Group categories by parent and treat unavailable parents as top-level for display
              final children = <int?, List<EntryCategory>>{};
              final ids = state.categories.map((c) => c.id).toSet();
              for (final category in state.categories) {
                final parent = ids.contains(category.parentId)
                    ? category.parentId
                    : null;
                children.putIfAbsent(parent, () => []).add(category);
              }
              final rows = <(EntryCategory, int)>[];
              final visited = <int>{};
              // Flatten only expanded branches and track visited IDs to guard against cycles
              void add(EntryCategory category, int depth) {
                if (!visited.add(category.id)) return;
                rows.add((category, depth));
                if (_expanded.contains(category.id)) {
                  for (final child
                      in children[category.id] ?? <EntryCategory>[]) {
                    add(child, depth + 1);
                  }
                }
              }

              for (final root in children[null] ?? <EntryCategory>[]) {
                add(root, 0);
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OutlinedButton.icon(
                    onPressed: state.isSaving ? null : () => _form(),
                    icon: const Icon(Icons.add),
                    label: Text(
                      AppLocalizations.of(context)!.createNewCategory,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        for (final row in rows) ...[
                          ListTile(
                            contentPadding: EdgeInsets.only(
                              left: 8 + row.$2.clamp(0, 5) * 12.0,
                              right: 4,
                            ),
                            leading: IconButton(
                              tooltip: _expanded.contains(row.$1.id)
                                  ? AppLocalizations.of(context)!.collapse
                                  : AppLocalizations.of(context)!.expand,
                              icon: Icon(
                                children[row.$1.id]?.isNotEmpty == true
                                    ? (_expanded.contains(row.$1.id)
                                          ? Icons.expand_more
                                          : Icons.chevron_right)
                                    : Icons.folder_outlined,
                                size: 20,
                              ),
                              onPressed: children[row.$1.id]?.isNotEmpty != true
                                  ? null
                                  : () => setState(() {
                                      if (!_expanded.add(row.$1.id))
                                        _expanded.remove(row.$1.id);
                                    }),
                            ),
                            title: Text(row.$1.name),
                            onLongPress: state.isSaving
                                ? null
                                : () => CategoryActions.show(context, row.$1),
                            subtitle: row.$1.isDefault
                                ? Text(
                                    AppLocalizations.of(context)!
                                        .defaultCategory,
                                  )
                                : null,
                            onTap: () {
                              context.read<CategoryCubit>().selectCategory(
                                row.$1.id,
                              );
                              Navigator.pop(context);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: AppLocalizations.of(context)!
                                      .addSubcategory,
                                  icon: const Icon(Icons.add, size: 19),
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _form(parentId: row.$1.id),
                                ),
                                PopupMenuButton<String>(
                                  enabled: !state.isSaving,
                                  icon: const Icon(Icons.more_vert, size: 19),
                                  onSelected: (value) => value == 'edit'
                                      ? _form(category: row.$1)
                                      : _delete(row.$1),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(
                                        AppLocalizations.of(context)!
                                            .renameMove,
                                      ),
                                    ),
                                    if (!row.$1.isDefault)
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          AppLocalizations.of(context)!.delete,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (row != rows.last)
                            const Divider(indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
