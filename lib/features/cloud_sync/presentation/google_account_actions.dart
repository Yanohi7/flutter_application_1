import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/database_helper.dart';
import 'cloud_sync_controller.dart';
import 'cloud_sync_messages.dart';
import 'google_sign_in_button.dart';

Future<void> showWorkspaceAccounts(
  BuildContext context,
  CloudSyncController sync,
) async {
  if (sync.busy || sync.profile.saving) return;
  final accounts = await sync.localAccounts();
  if (!context.mounted || sync.busy) return;
  final l10n = AppLocalizations.of(context)!;
  final selected = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.switchAccount,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final account in accounts)
          ListTile(
            leading: CircleAvatar(
              foregroundImage: account.avatar == null
                  ? null
                  : MemoryImage(account.avatar!),
              child: const Icon(Icons.person_outline),
            ),
            title: Text(
              account.isGuest && account.displayName == 'Guest'
                  ? l10n.guest
                  : account.displayName,
            ),
            subtitle: Text(
              account.isGuest
                  ? l10n.entriesSavedOnThisDevice
                  : (account.googleEmail ?? l10n.googleAccount),
            ),
            selected: account.id == sync.activeUserId,
            trailing: account.id == sync.activeUserId
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(context, account),
          ),
        ListTile(
          leading: const Icon(Icons.person_add_outlined),
          title: Text(l10n.addGoogleAccount),
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (selected is LocalUserAccount) {
    await sync.selectAccount(selected);
  } else if (selected == true) {
    await sync.connect();
  }
}

class GoogleAccountActions extends StatelessWidget {
  const GoogleAccountActions({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncController?>();
    if (sync == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final hasCachedAccounts = sync.hasCachedGoogleAccounts;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!sync.hasGoogleWorkspace)
            Center(
              child: GoogleSignInButton(
                onPressed: sync.busy
                    ? null
                    : hasCachedAccounts
                    ? () => showWorkspaceAccounts(context, sync)
                    : sync.connect,
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.switch_account_outlined),
              title: Text(l10n.switchAccount),
              subtitle: Text(
                sync.profile.email ?? l10n.googleAccount,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: sync.busy
                  ? null
                  : () => showWorkspaceAccounts(context, sync),
            ),
          if (sync.accountBusy) const LinearProgressIndicator(),
          if (sync.accountMessage case final message?)
            Text(
              cloudSyncMessage(context, message),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
