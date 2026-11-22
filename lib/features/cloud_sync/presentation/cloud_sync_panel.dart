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
                      onPressed: sync.busy
                          ? null
                          : () => _syncNow(context, sync),
                      child: Text(
                        sync.needsGoogleAccess
                            ? l10n.reconnect
                            : sync.needsPrivateSyncPassword
                            ? l10n.unlock
                            : l10n.syncNow,
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

  Future<void> _syncNow(BuildContext context, CloudSyncController sync) =>
      sync.syncNow(
        requestPassword: ({required local, required copy}) async {
          if (!context.mounted) return null;
          final l10n = AppLocalizations.of(context)!;
          final password = await showWorkspacePrivatePassword(
            context,
            local
                ? l10n.localPrivatePassword
                : l10n.driveCopyPrivatePassword(copy),
          );
          if (password != null) await WidgetsBinding.instance.endOfFrame;
          return password;
        },
      );
}
