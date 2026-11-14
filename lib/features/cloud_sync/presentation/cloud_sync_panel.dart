import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cloud_sync_controller.dart';
import 'cloud_sync_messages.dart';
import 'guest_transfer_dialog.dart';

class CloudSyncPanel extends StatelessWidget {
  const CloudSyncPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncController?>();
    if (sync == null || !sync.hasGoogleWorkspace) {
      return const SizedBox.shrink();
    }
    final last = sync.lastSync?.toLocal();
    final l10n = AppLocalizations.of(context)!;
    final localization = MaterialLocalizations.of(context);
    final lastSync = last == null
        ? AppLocalizations.of(context)!.neverSynced
        : AppLocalizations.of(context)!.lastSync(
            localization.formatMediumDate(last),
            localization.formatTimeOfDay(TimeOfDay.fromDateTime(last)),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(AppLocalizations.of(context)!.googleDrive),
            ),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.autoSync),
              value: sync.autoSync,
              onChanged: sync.busy ? null : sync.setAutoSync,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sync.needsGoogleAccess
                          ? l10n.googleDriveReconnect
                          : lastSync,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton.tonal(
                      onPressed: sync.busy ? null : () => sync.syncNow(),
                      child: Text(
                        sync.needsGoogleAccess ? l10n.reconnect : l10n.syncNow,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (sync.guestTransferAvailable)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(AppLocalizations.of(context)!.moveGuestEntries),
                onTap: sync.busy
                    ? null
                    : () => offerGuestTransfer(context, sync),
              ),
            if (sync.conflict != null)
              ListTile(
                leading: const Icon(Icons.sync_problem),
                title: Text(
                  AppLocalizations.of(context)!.differentVersionsFound,
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!
                      .keepYourEntriesAndImportDifferingDriveEntriesAsCopies,
                ),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 84),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: sync.busy
                        ? null
                        : () => _reviewConflict(context, sync),
                    child: Text(
                      AppLocalizations.of(context)!.review,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (sync.busy && !sync.accountBusy) const LinearProgressIndicator(),
            if (sync.message case final String message)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(cloudSyncMessage(context, message)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewConflict(
    BuildContext context,
    CloudSyncController sync,
  ) async {
    final keepBoth = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(AppLocalizations.of(context)!.keepBothVersions),
        content: Text(
          AppLocalizations.of(
            context,
          )!.yourLocalEntriesAndProfileStayInPlaceDifferentEntriesFromGoogleDriveAreAddedToAGoogleDriveCopiesCategoryWithTh,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.keepBoth),
          ),
        ],
      ),
    );
    if (keepBoth == true && context.mounted) {
      await sync.keepBothCopies(
        requestPassword: ({required local, required copy}) => context.mounted
            ? showDialog<String>(
                context: context,
                builder: (_) =>
                    _PrivateCopyPasswordDialog(local: local, copy: copy),
              )
            : Future.value(null),
      );
    }
  }
}

class _PrivateCopyPasswordDialog extends StatefulWidget {
  const _PrivateCopyPasswordDialog({required this.local, required this.copy});

  final bool local;
  final int copy;

  @override
  State<_PrivateCopyPasswordDialog> createState() =>
      _PrivateCopyPasswordDialogState();
}

class _PrivateCopyPasswordDialogState
    extends State<_PrivateCopyPasswordDialog> {
  final _password = TextEditingController();

  void _submit() {
    if (_password.text.isNotEmpty) Navigator.pop(context, _password.text);
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.local
            ? l10n.localPrivatePassword
            : l10n.driveCopyPrivatePassword(widget.copy),
      ),
      content: TextField(
        controller: _password,
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        autofillHints: null,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: l10n.enterYourPrivatePassword),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.unlock)),
      ],
    );
  }
}
