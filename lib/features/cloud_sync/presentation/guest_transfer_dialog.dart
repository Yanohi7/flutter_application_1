import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'cloud_sync_controller.dart';
import 'cloud_sync_messages.dart';

Future<void> offerGuestTransfer(
  BuildContext context,
  CloudSyncController sync,
) async {
  final l10n = AppLocalizations.of(context)!;
  final move = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(l10n.moveGuestEntries),
      content: Text(
        l10n.moveGuestEntriesDescription(
          sync.profile.email ?? l10n.googleAccount,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.moveGuestEntries),
        ),
      ],
    ),
  );
  if (move == true && context.mounted) {
    final error = await sync.transferGuestEntries(l10n.entriesFromThisDevice);
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cloudSyncMessage(context, error))));
    }
  }
}
