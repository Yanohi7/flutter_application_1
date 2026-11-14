import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/widgets/app_ui.dart';
import '../../domain/entities/entry.dart';
import '../cubit/entry_cubit.dart';
import '../cubit/entry_state.dart';
import '../widgets/entry_actions.dart';
import 'entry_editor_page.dart';

class EntryDetailsPage extends StatelessWidget {
  const EntryDetailsPage({super.key, required this.entryId});
  final int? entryId;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<EntryCubit, EntryState, Entry?>(
        selector: (state) {
          for (final entry in state.entries) {
            if (entry.id == entryId) return entry;
          }
          return null;
        },
        builder: (context, entry) {
          if (entry == null) {
            final loading = context.select(
              (EntryCubit cubit) => cubit.state.status == EntryStatus.loading,
            );
            return Scaffold(
              appBar: AppBar(title: Text(AppLocalizations.of(context)!.entry)),
              body: Center(
                child: WallpaperTextSurface(
                  child: Text(
                    loading
                        ? AppLocalizations.of(context)!.loading
                        : AppLocalizations.of(context)!
                              .thisEntryIsNoLongerAvailable,
                  ),
                ),
              ),
            );
          }
          return EntryEditorPage(
            key: ValueKey(entry.id),
            entry: entry,
            onActions: (current) async {
              final deleted = await EntryActions.show(
                context,
                current,
                showEdit: false,
              );
              if (context.mounted && deleted) Navigator.pop(context);
            },
          );
        },
      );
}
