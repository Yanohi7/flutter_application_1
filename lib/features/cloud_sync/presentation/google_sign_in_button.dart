import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Sign in with Google',
      child: Opacity(
        opacity: onPressed == null ? .55 : 1,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              'assets/images/google-sign-in-$variant.png',
              height: 40,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
