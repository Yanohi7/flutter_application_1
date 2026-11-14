// Share category edit, move and delete menus between navigation chips and the management tree

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../entry/presentation/cubit/entry_cubit.dart';
import '../../domain/entities/entry_category.dart';
import '../cubit/category_cubit.dart';
import '../cubit/category_state.dart';
import '../pages/category_create_page.dart';
import '../pages/category_delete_page.dart';

enum _CategoryAction { edit, delete }

class CategoryActions {
  static Future<void> show(BuildContext context, EntryCategory category) async {
    final cubit = context.read<CategoryCubit>();
    if (cubit.state.isSaving || cubit.state.status != CategoryStatus.success)
      return;

    final action = await showAppDialog<_CategoryAction>(
      context: context,
      builder: (sheetContext) => AppDialog(
        title: category.name,
        onClose: () => Navigator.pop(sheetContext),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppLocalizations.of(context)!.editMove),
              onTap: () => Navigator.pop(sheetContext, _CategoryAction.edit),
            ),
            if (!category.isDefault)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(AppLocalizations.of(context)!.delete),
                onTap: () =>
                    Navigator.pop(sheetContext, _CategoryAction.delete),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null || cubit.state.isSaving) return;

    // Reuse validation and deletion confirmation rather than deleting from the menu directly
    final bool changed;
    if (action == _CategoryAction.edit) {
      changed = await showCategoryEditor(context, category: category) != null;
    } else {
      changed = await showCategoryDeleteDialog(context, category) == true;
    }
    if (context.mounted && changed) {
      await context.read<EntryCubit>().loadEntries();
    }
  }
}
