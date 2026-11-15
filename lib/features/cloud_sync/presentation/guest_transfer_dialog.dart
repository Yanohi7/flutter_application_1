import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import '../../../core/security/private_content_store.dart';
import 'cloud_sync_controller.dart';
import 'cloud_sync_messages.dart';

Future<void> offerGuestTransfer(
  BuildContext context,
  CloudSyncController sync,
) async {
  try {
    final hasPrivate = await sync.guestHasPrivateEntries();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuestTransferDialog(sync: sync, hasPrivate: hasPrivate),
    );
  } finally {
    sync.finishGuestTransferOffer();
  }
}

class _GuestTransferDialog extends StatefulWidget {
  const _GuestTransferDialog({required this.sync, required this.hasPrivate});

  final CloudSyncController sync;
  final bool hasPrivate;

  @override
  State<_GuestTransferDialog> createState() => _GuestTransferDialogState();
}

class _GuestTransferDialogState extends State<_GuestTransferDialog> {
  bool _moving = false;
  String? _error;

  Future<void> _move({bool skipPrivate = false}) async {
    if (_moving) return;
    setState(() {
      _moving = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    final error = await widget.sync.transferGuestEntries(
      skipPrivate: skipPrivate,
      unlockPrompt: l10n.privateInformation,
      requestPassword:
          ({required guest, required creating, required allowDevice}) {
            if (!mounted) return Future.value(null);
            return showDialog<({String? password, bool useDevice})>(
              context: context,
              builder: (_) => _WorkspacePrivatePasswordDialog(
                title: creating
                    ? (guest
                          ? l10n.setANewPrivatePassword
                          : l10n.createTargetPrivatePassword)
                    : (guest
                          ? l10n.guestPrivatePassword
                          : l10n.localPrivatePassword),
                creating: creating,
                allowDevice: allowDevice,
              ),
            );
          },
    );
    if (!mounted) return;
    if (error == null || error == 'Guest transfer canceled.') {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _moving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_moving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.moveGuestEntries),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.moveGuestEntriesDescription(
                widget.sync.profile.email ?? l10n.googleAccount,
              ),
            ),
            if (widget.hasPrivate) ...[
              const SizedBox(height: 8),
              Text(l10n.privateEntriesStayInGuest),
            ],
            if (_moving) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(semanticsLabel: l10n.movingGuestEntries),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Text(
                cloudSyncMessage(
                  context,
                  error,
                  fallback: l10n.couldNotMoveGuestEntries,
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.hasPrivate)
            TextButton(
              onPressed: _moving ? null : () => _move(skipPrivate: true),
              child: Text(l10n.moveWithoutPrivateEntries),
            ),
          TextButton(
            onPressed: _moving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _moving ? null : _move,
            child: Text(
              _moving ? l10n.movingGuestEntries : l10n.moveGuestEntries,
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showWorkspacePrivatePassword(
  BuildContext context,
  String title,
) async => (await showDialog<({String? password, bool useDevice})>(
  context: context,
  builder: (_) => _WorkspacePrivatePasswordDialog(title: title),
))?.password;

class _WorkspacePrivatePasswordDialog extends StatefulWidget {
  const _WorkspacePrivatePasswordDialog({
    required this.title,
    this.creating = false,
    this.allowDevice = false,
  });

  final String title;
  final bool creating;
  final bool allowDevice;

  @override
  State<_WorkspacePrivatePasswordDialog> createState() =>
      _WorkspacePrivatePasswordDialogState();
}

class _WorkspacePrivatePasswordDialogState
    extends State<_WorkspacePrivatePasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  bool _showPassword = false;
  bool _showConfirmation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onInactive: () {
      if (!_showPassword && !_showConfirmation) return;
      setState(() {
        _showPassword = false;
        _showConfirmation = false;
      });
    });
  }

  void _submit() {
    final password = _password.text;
    if (widget.creating &&
        (password.length < PrivateContentStore.minimumPasswordLength ||
            password != _confirmation.text)) {
      setState(
        () =>
            _error = AppLocalizations.of(context)!
                .useAtLeast6CharactersAndEnterTheSamePasswordTwice,
      );
      return;
    }
    if (password.isNotEmpty) {
      Navigator.pop(context, (password: password, useDevice: false));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _passwordField(
            _password,
            l10n.enterYourPrivatePassword,
            autofocus: true,
          ),
          if (widget.creating) ...[
            const SizedBox(height: 12),
            _passwordField(_confirmation, l10n.repeatPrivatePassword),
          ],
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (widget.allowDevice)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, (
              password: null as String?,
              useDevice: true,
            )),
            child: Text(l10n.unlock),
          ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.creating ? l10n.createPassword : l10n.enterPassword,
          ),
        ),
      ],
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final confirming = controller == _confirmation;
    final visible = confirming ? _showConfirmation : _showPassword;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      onSubmitted: (_) {
        if (!(autofocus && widget.creating)) _submit();
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: visible
              ? l10n.hidePrivateEntryPassword
              : l10n.showPrivateEntryPassword,
          onPressed: () => setState(() {
            if (confirming) {
              _showConfirmation = !_showConfirmation;
            } else {
              _showPassword = !_showPassword;
            }
          }),
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
