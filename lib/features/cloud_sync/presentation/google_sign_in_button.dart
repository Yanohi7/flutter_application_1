import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      icon: Image.asset(
        'assets/images/google-mark.png',
        width: 18,
        height: 18,
        excludeFromSemantics: true,
      ),
      label: Text(AppLocalizations.of(context)!.signInWithGoogle),
    );
  }
}
