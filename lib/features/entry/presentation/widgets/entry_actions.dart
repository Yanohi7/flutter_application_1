import 'package:flutter_application_1/l10n/app_localizations.dart';

import '../../../category/presentation/pages/category_create_page.dart';
// Share edit, move, duplicate and delete flows between card menus and the entry reading page

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../category/presentation/cubit/category_cubit.dart';
import '../../../category/presentation/cubit/category_state.dart';
import '../../../category/presentation/widgets/category_picker.dart';
import '../../domain/entities/entry.dart';
import '../cubit/entry_cubit.dart';
import '../cubit/entry_state.dart';
import '../entry_playback.dart';
import '../pages/entry_details_page.dart';

enum EntryAction { edit, move, duplicate, delete }

class EntryActions {
  static bool _busy(EntryCubit cubit) =>
      cubit.state.isWriting || cubit.state.status != EntryStatus.ready;

  static void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static Future<void> edit(BuildContext context, Entry entry) async {
    if (_busy(context.read<EntryCubit>())) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EntryDetailsPage(entryId: entry.id)),
    );
  }

  // Return true only when the original entry was deleted
  static Future<bool> show(
    BuildContext context,
    Entry entry, {
    bool showEdit = true,
  }) async {
    final cubit = context.read<EntryCubit>();
    if (_busy(cubit)) return false;

    final action = await showModalBottomSheet<EntryAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        Widget item(EntryAction action, String label, IconData icon) {
          return ListTile(
            leading: Icon(
              icon,
              color: action == EntryAction.delete
                  ? Theme.of(sheetContext).colorScheme.error
                  : null,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: action == EntryAction.delete
                    ? Theme.of(sheetContext).colorScheme.error
                    : null,
              ),
            ),
            onTap: () => Navigator.pop(sheetContext, action),
          );
        }

        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (showEdit)
                item(
                  EntryAction.edit,
                  AppLocalizations.of(context)!.edit,
                  Icons.edit_outlined,
                ),
              item(
                EntryAction.move,
                AppLocalizations.of(context)!.move,
                Icons.drive_file_move_outlined,
              ),
              item(
                EntryAction.duplicate,
                AppLocalizations.of(context)!.duplicate,
                Icons.copy_outlined,
              ),
              item(
                EntryAction.delete,
                AppLocalizations.of(context)!.delete,
                Icons.delete_outline,
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || action == null || _busy(cubit)) return false;

    switch (action) {
      case EntryAction.edit:
        await edit(context, entry);
        return false;

      // Update the original entry with a different category while keeping its existing ID
      case EntryAction.move:
        final categories = context.read<CategoryCubit>();
        if (categories.state.isSaving) return false;

        if (categories.state.status != CategoryStatus.success) {
          await categories.loadCategories();
        }

        if (!context.mounted) return false;
        if (categories.state.status != CategoryStatus.success) {
          _message(
            context,
            AppLocalizations.of(context)!.categoriesAreNotReadyPleaseTryAgain,
          );
          return false;
        }

        final selection = await showCategoryPicker(
          onCreateCategory: (dialogContext) =>
              showCategoryEditor(dialogContext),
          context: context,
          categories: categories.state.categories,
          selectedId: entry.categoryId,
          title: AppLocalizations.of(context)!.moveEntry,
        );

        final target = selection?.category;
        if (!context.mounted ||
            target == null ||
            target.id == entry.categoryId) {
          return false;
        }

        final moved = await cubit.saveEntry(
          original: entry,
          title: entry.title ?? AppLocalizations.of(context)!.untitled,
          content: entry.content,
          privateContent: entry.privateContent,
          isPinned: entry.isPinned,
          isFavorite: entry.isFavorite,
          category: (id: target.id, name: target.name),
        );

        if (context.mounted && moved != null) {
          _message(context, AppLocalizations.of(context)!.entryMoved);
        }
        return false;

      case EntryAction.duplicate:
        // Create a new text entry with a new ID and new timestamps
        final copied = await cubit.saveEntry(
          title:
              '${entry.title ?? AppLocalizations.of(context)!.untitled} (copy)',
          content: entry.content,
          privateContent: entry.privateContent,
          isPinned: entry.isPinned,
          isFavorite: entry.isFavorite,
          category: (id: entry.categoryId, name: entry.categoryName),
        );

        if (context.mounted && copied != null) {
          _message(context, AppLocalizations.of(context)!.entryDuplicated);
        }
        return false;

      case EntryAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(AppLocalizations.of(context)!.deleteTheEntry),
            content: Text(
              '“${entry.title ?? AppLocalizations.of(context)!.untitled}” and its attachments will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
        );

        if (!context.mounted || confirmed != true) return false;
        final playback = context.read<EntryPlayback>();
        final path = playback.track?.localPath;
        if (path != null &&
            entry.attachments.any((file) => file.localPath == path)) {
          await playback.stopIfPath(path);
          if (!context.mounted) return false;
        }
        return cubit.removeEntry(entry);
    }
  }
}
