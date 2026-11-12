import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cloud_sync_controller.dart';
import 'google_sign_in_button.dart';

enum _AccountAction { reconnect, signOut }

class GoogleAccountActions extends StatelessWidget {
  const GoogleAccountActions({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncController?>();
    if (sync == null) return const SizedBox.shrink();
    final account = sync.isConnected ? sync.account : null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (account == null)
            GoogleSignInButton(onPressed: sync.busy ? null : sync.connect)
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Google account'),
              subtitle: Text(account.email, overflow: TextOverflow.ellipsis),
              trailing: PopupMenuButton<_AccountAction>(
                tooltip: 'Google account options',
                enabled: !sync.busy,
                onSelected: (action) {
                  switch (action) {
                    case _AccountAction.reconnect:
                      sync.connect();
                    case _AccountAction.signOut:
                      sync.disconnect();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _AccountAction.reconnect,
                    child: Text('Reconnect'),
                  ),
                  PopupMenuItem(
                    value: _AccountAction.signOut,
                    child: Text('Sign out'),
                  ),
                ],
              ),
            ),
          if (sync.accountBusy) const LinearProgressIndicator(),
          if (sync.accountMessage case final message?)
            Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
