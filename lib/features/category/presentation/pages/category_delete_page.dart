// Show deletion impact counts and require confirmation before removing a category branch

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/features/category/presentation/category_display_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../domain/entities/entry_category.dart';
import '../../domain/results/category_deletion_summary.dart';
import '../cubit/category_cubit.dart';

Future<bool?> showCategoryDeleteDialog(
  BuildContext context,
  EntryCategory category,
) => showAppDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => BlocProvider.value(
    value: context.read<CategoryCubit>(),
    child: CategoryDeletePage(category: category),
  ),
);

class CategoryDeletePage extends StatefulWidget {
  final EntryCategory category;

  const CategoryDeletePage({super.key, required this.category});

  @override
  State<CategoryDeletePage> createState() => _CategoryDeletePageState();
}

class _CategoryDeletePageState extends State<CategoryDeletePage> {
  CategoryDeletionSummary? _summary;
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  // Load affected counts for confirmation while keeping deletion disabled until they arrive
  Future<void> _loadSummary() async {
    if (widget.category.isDefault) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!
            .theDefaultCategoryCannotBeDeleted;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final cubit = context.read<CategoryCubit>();
    final summary = await cubit.getDeletionSummary(widget.category.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _summary = summary;
      if (summary == null) {
        _error =
            cubit.state.errorMessage ??
            AppLocalizations.of(context)!.couldNotLoadDeletionDetails;
      }
    });
  }

  Future<void> _deleteCategory() async {
    // Block deletion until counts are loaded and prevent deleting the default category
    if (_deleting || _loading || _summary == null || widget.category.isDefault)
      return;

    final cubit = context.read<CategoryCubit>();

    setState(() {
      _deleting = true;
      _error = null;
    });

    final deleted = await cubit.deleteCategory(widget.category.id);

    if (!mounted) return;

    if (!deleted) {
      setState(() {
        _deleting = false;
        _error =
            cubit.state.errorMessage ??
            AppLocalizations.of(context)!.couldNotDeleteCategoryPleaseTryAgain;
      });
      return;
    }

    setState(() {
      _deleting = false;
    });

    // Let PopScope rebuild after clearing the deleting flag before closing this route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      // Keep the confirmation page open while storage is changing
      canPop: !_deleting,
      child: AppDialog(
        title: AppLocalizations.of(context)!.deleteCategory,
        onClose: _deleting ? null : () => Navigator.pop(context, false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!
                  .categoryDisplayName(widget.category.name),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (summary != null) ...[
              Text(
                AppLocalizations.of(context)!
                    .deletingThisCategoryWillAlsoDelete,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  AppLocalizations.of(context)!
                      .categoryCount(summary.descendantCategoryCount),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.includesAllNestedLevels,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  AppLocalizations.of(context)!.entryCount(summary.entryCount),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.includesTheirAttachments,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.thisActionCannotBeUndoneInTheApp,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: colors.error)),
              if (summary == null && !widget.category.isDefault)
                TextButton(
                  onPressed: _loading ? null : _loadSummary,
                  child: Text(AppLocalizations.of(context)!.retry),
                ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TextButton(
                  onPressed: _deleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton.icon(
                  onPressed:
                      _loading ||
                          _deleting ||
                          summary == null ||
                          widget.category.isDefault
                      ? null
                      : _deleteCategory,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(
                    _deleting
                        ? AppLocalizations.of(context)!.deleting
                        : AppLocalizations.of(context)!.deleteCategory,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
