// Show a fixed masked placeholder without decrypting or exposing the private text length

import 'package:flutter/material.dart';

import '../pages/private_content_page.dart';

class PrivateContentTile extends StatelessWidget {
  const PrivateContentTile({
    super.key,
    required this.payload,
    this.onChanged,
    this.isEnabled = true,
  });
  final String payload;
  final ValueChanged<String>? onChanged;
  final bool isEnabled;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lock_outline_rounded),
      title: const Text('Private information'),
      subtitle: Text(
        payload.isEmpty
            ? 'Passwords and sensitive text'
            : '•••••••• · Unlock to view',
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: !isEnabled
          ? null
          : () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => PrivateContentPage(
                    payload: payload,
                    isEditable: onChanged != null,
                  ),
                ),
              );
              if (context.mounted && result != null) onChanged?.call(result);
            },
    ),
  );
}
