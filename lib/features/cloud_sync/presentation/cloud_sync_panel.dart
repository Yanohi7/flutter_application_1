import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cloud_sync_controller.dart';

class CloudSyncPanel extends StatelessWidget {
  const CloudSyncPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncController?>();
    if (sync == null || !sync.isConnected) return const SizedBox.shrink();
    final last = sync.lastSync?.toLocal();
    final localization = MaterialLocalizations.of(context);
    final lastSync = last == null
        ? 'Never synced'
        : 'Last sync · ${localization.formatMediumDate(last)}, '
              '${localization.formatTimeOfDay(TimeOfDay.fromDateTime(last))}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Google Drive'),
            ),
            SwitchListTile(
              title: const Text('Auto-sync'),
              value: sync.autoSync,
              onChanged: sync.busy ? null : sync.setAutoSync,
            ),
            ListTile(
              title: Text(lastSync),
              trailing: FilledButton.tonal(
                onPressed: sync.busy ? null : () => sync.syncNow(),
                child: const Text('Sync now'),
              ),
            ),
            if (sync.conflict != null)
              ListTile(
                leading: const Icon(Icons.sync_problem),
                title: const Text('Different versions found'),
                subtitle: const Text(
                  'Keep your entries and import differing Drive entries as copies.',
                ),
                trailing: TextButton(
                  onPressed: sync.busy
                      ? null
                      : () => _reviewConflict(context, sync),
                  child: const Text('Review'),
                ),
              ),
            if (sync.busy && !sync.accountBusy) const LinearProgressIndicator(),
            if (sync.message case final String message)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(liveRegion: true, child: Text(message)),
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
        title: const Text('Keep both versions?'),
        content: const Text(
          'Your local entries and profile stay in place. Different entries from Google Drive are added to a Google Drive copies category, with their attachments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep both'),
          ),
        ],
      ),
    );
    if (keepBoth == true && context.mounted) await sync.keepBothCopies();
  }
}
