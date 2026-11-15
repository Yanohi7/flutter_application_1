// Build root and child category chip rows while keeping the selected ancestor path visible

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/features/category/presentation/category_display_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entry_category.dart';
import '../cubit/category_cubit.dart';
import '../cubit/category_state.dart';
import 'category_chip_row.dart';
import 'category_actions.dart';

class CategoriesNavigation extends StatefulWidget {
  final bool isPreview;
  const CategoriesNavigation({super.key, this.isPreview = false});

  @override
  State<CategoriesNavigation> createState() => _CategoriesNavigationState();
}

class _CategoriesNavigationState extends State<CategoriesNavigation> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CategoryCubit, CategoryState>(
      listenWhen: (before, after) =>
          before.selectedCategoryId != after.selectedCategoryId,
      listener: (context, state) {
        if (_collapsed) setState(() => _collapsed = false);
      },
      builder: (context, state) {
        // Read the Cubit to call actions while BlocConsumer provides the rebuild subscription
        final cubit = context.read<CategoryCubit>();

        if (state.status == CategoryStatus.initial ||
            state.status == CategoryStatus.loading) {
          return const LinearProgressIndicator();
        }

        if (state.status == CategoryStatus.failure) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.errorMessage ??
                    AppLocalizations.of(context)!.failedToLoadCategories,
              ),

              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => cubit.loadCategories(),
                icon: const Icon(Icons.refresh),
                label: Text(
                  AppLocalizations.of(context)!.retryLoadingCategories,
                ),
              ),
            ],
          );
        }

        final enabled = !state.isSaving;
        final isAllEntries =
            widget.isPreview || state.selectedCategoryId == null;

        final roots = state.categories.where((category) => category.isRoot);

        final path = isAllEntries
            ? const <EntryCategory>[]
            : state.selectedPath;

        final rootId = path.isEmpty ? null : path.first.id;

        // Keep ancestor rows visible so a selected child does not disappear when it is opened
        final parents = path.where((parent) {
          return parent.id == rootId ||
              state.categories.any(
                (category) => category.parentId == parent.id,
              );
        }).toList();

        // The root row and the first child row remain visible
        final visibleParents = _collapsed ? parents.take(1) : parents;

        void select(int? id) {
          setState(() => _collapsed = false);
          cubit.selectCategory(id);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row([
              _chip(
                label: AppLocalizations.of(context)!.allEntries,
                selected: isAllEntries,
                onTap: enabled ? () => select(null) : null,
              ),
              for (final category in roots)
                _chip(
                  label: AppLocalizations.of(context)!
                      .categoryDisplayName(category.name),
                  onLongPress: enabled
                      ? () => CategoryActions.show(context, category)
                      : null,
                  selected: !isAllEntries && rootId == category.id,
                  onTap: enabled ? () => select(category.id) : null,
                ),
            ]),
            if (!isAllEntries) ...[
              const Divider(height: 14),
              // Ordinary categories show their direct entries and their own children at each visible level
              for (final parent in visibleParents) ...[
                const SizedBox(height: 6),

                _row([
                  _chip(
                    label: AppLocalizations.of(context)!.directEntries,
                    onLongPress: enabled
                        ? () => CategoryActions.show(context, parent)
                        : null,
                    selected: state.selectedCategoryId == parent.id,
                    onTap: enabled ? () => select(parent.id) : null,
                  ),

                  for (final child in state.categories.where(
                    (category) => category.parentId == parent.id,
                  ))
                    _chip(
                      label: AppLocalizations.of(context)!
                          .categoryDisplayName(child.name),
                      onLongPress: enabled
                          ? () => CategoryActions.show(context, child)
                          : null,

                      // Highlight the category on the selected branch
                      selected: path.any((category) => category.id == child.id),

                      onTap: enabled ? () => select(child.id) : null,
                    ),
                ], key: ValueKey('category-children-${parent.id}')),
              ],
              if (parents.length > 1)
                TextButton.icon(
                  onPressed: enabled
                      ? () => setState(() => _collapsed = !_collapsed)
                      : null,
                  icon: Icon(
                    _collapsed ? Icons.expand_more : Icons.expand_less,
                  ),
                  label: Text(
                    _collapsed
                        ? AppLocalizations.of(context)!.showMoreLevels
                        : AppLocalizations.of(context)!.collapseToTwoRows,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _row(List<Widget> children, {Key? key}) {
    return CategoryChipRow(key: key, children: children);
  }

  // Build one selection control and disable it when no tap callback is available
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    IconData? icon,
    VoidCallback? onLongPress,
  }) {
    // The wrapper adds category actions while ChoiceChip keeps its normal selection behavior
    return GestureDetector(
      onLongPress: onLongPress,
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        selected: selected,
        selectedColor: Theme.of(context).colorScheme.primary,
        showCheckmark: false,
        avatar: icon == null ? null : Icon(icon, size: 18),
        onSelected: onTap == null ? null : (_) => onTap(),
      ),
    );
  }
}
