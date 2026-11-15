// Show a fixed masked placeholder without decrypting or exposing the private text length

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PrivateContentTile extends StatelessWidget {
  const PrivateContentTile({super.key, required this.onTap});

  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lock_outline_rounded),
      title: Text(AppLocalizations.of(context)!.privateInformation),
      subtitle: Text(AppLocalizations.of(context)!.unlockToView),
      trailing: const Icon(Icons.expand_more, size: 20),
      onTap: onTap,
    ),
  );
}
