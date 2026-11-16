// Keep decrypted private text in a short-lived authenticated screen and return only ciphertext
import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/security/private_content_store.dart';
import '../../domain/entities/private_entry_content.dart';

/// Lets the note editor encrypt the current private draft before saving the note.
class PrivateContentEditorController {
  Future<String?> Function()? _commit;
  Future<String?> commit() async => _commit == null ? null : await _commit!();
  bool get isAttached => _commit != null;
}

class PrivateContentPage extends StatefulWidget {
  const PrivateContentPage({
    super.key,
    required this.payload,
    required this.isEditable,
    this.embedded = false,
    this.securitySettings = false,
    this.onChanged,
    this.onDirtyChanged,
    this.onCollapse,
    this.controller,
  });
  final String payload;
  final bool isEditable;
  final bool embedded;
  final bool securitySettings;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onCollapse;
  final PrivateContentEditorController? controller;
  @override
  State<PrivateContentPage> createState() => _PrivateContentPageState();
}

class _PrivateContentPageState extends State<PrivateContentPage>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<PrivateContentPage> {
  @override
  bool get wantKeepAlive => widget.embedded;

  final _text = TextEditingController();
  final _login = TextEditingController();
  final _entryPassword = TextEditingController();
  bool _showCredentials = false;
  bool _showEntryPassword = false;

  String get _privateDraft => PrivateEntryContent(
    _text.text,
    login: _login.text,
    password: _entryPassword.text,
  ).encode();

  void _clearPrivateDraft() {
    _showEntryPassword = false;
    _showCredentials = false;
    _text.clear();
    _login.clear();
    _entryPassword.clear();
  }

  void _markPrivateDraftChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
      widget.onDirtyChanged?.call(true);
    }
    _restartTimer();
  }

  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmation = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _isPasswordConfigured = false;
  bool _isBiometricEnabled = false;
  bool _hasDeviceRecovery = false;
  bool _isReady = false;
  late String _payload = widget.payload;
  SecretKeyData? _key;
  Timer? _lockTimer;
  bool _isLocked = true;
  bool _isWorking = false;
  bool _isAuthenticating = false;
  bool _isDirty = false;
  bool _isLeaving = false;
  bool _isScreenProtected = false;
  bool _isAskingToLeave = false;
  bool _isChangingPassword = false;
  Completer<void>? _waitingForResume;
  int _generation = 0;
  String? _error;

  void _clearPasswordFields() {
    _password.clear();
    _confirmation.clear();
    _showPassword = false;
    _showConfirmation = false;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._commit = _commitEmbedded;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    try {
      await PrivateContentStore.protectScreen(true);
      final isConfigured = await PrivateContentStore.hasPassword();
      final isBiometric = await PrivateContentStore.hasBiometrics().catchError(
        (Object _) => false,
      );
      final hasDeviceRecovery = await PrivateContentStore.hasDeviceRecovery()
          .catchError((Object _) => false);
      if (!mounted) return;
      setState(() {
        _isScreenProtected = true;
        _isPasswordConfigured = isConfigured;
        _isBiometricEnabled = isBiometric;
        _hasDeviceRecovery = hasDeviceRecovery;
        _isReady = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!
                  .privateStorageIsUnavailableOnThisDevice,
        );
      }
    }
  }

  Future<void> _savePassword() async {
    if (_isWorking || _key == null) return;
    if (_password.text.length < PrivateContentStore.minimumPasswordLength ||
        _password.text != _confirmation.text) {
      setState(
        () =>
            _error = AppLocalizations.of(context)!
                .useAtLeast6CharactersAndEnterTheSamePasswordTwice,
      );
      return;
    }
    _lockTimer?.cancel();
    final key = _key!;
    final value = widget.isEditable && _isDirty ? _privateDraft : null;
    final password = _password.text;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isWorking = true);
    try {
      if (value != null) {
        _payload = await PrivateContentStore.encrypt(value, key);
      }
      await PrivateContentStore.setPassword(key, password);
      if (mounted) {
        TextInput.finishAutofillContext(shouldSave: true);
        setState(() {
          _isPasswordConfigured = true;
          _hasDeviceRecovery = PrivateContentStore.supportsBiometrics;
          _isChangingPassword = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = switch (error) {
            PrivateRecoveryFailure.noScreenLock =>
              l10n.screenLockSetupInstructions,
            PrivateRecoveryFailure.setup => l10n.privateRecoverySetupFailed,
            _ => l10n.couldNotSaveThePrivatePasswordPleaseTryAgain,
          };
        });
      }
    } finally {
      if (mounted) {
        _clearPasswordFields();
        setState(() => _isWorking = false);
        // If the app lost focus while saving, discard the unlocked key as well
        if (_isLocked) {
          _key?.destroy();
          _key = null;
        } else {
          _restartTimer();
        }
      }
    }
  }

  void _restartTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(seconds: 60), _lock);
  }

  Future<bool> _waitForForeground() async {
    if (!mounted) return false;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return true;
    }
    final resumed = _waitingForResume = Completer<void>();
    try {
      await resumed.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return false;
    } finally {
      _waitingForResume = null;
    }
    return mounted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _unlock({
    bool isBiometric = false,
    bool useDeviceRecovery = false,
    bool resetPassword = false,
  }) async {
    if (_isWorking || !_isReady) return;
    final isPassword = !isBiometric && !useDeviceRecovery;
    final isCreating = isPassword && !_isPasswordConfigured;
    if (isCreating &&
        (_password.text.length < PrivateContentStore.minimumPasswordLength ||
            _password.text != _confirmation.text)) {
      setState(
        () =>
            _error = AppLocalizations.of(context)!
                .useAtLeast6CharactersAndEnterTheSamePasswordTwice,
      );
      return;
    }
    final password = _password.text;
    final generation = ++_generation;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isWorking = true;
      _isAuthenticating = !isPassword;
      _error = null;
    });
    SecretKeyData? key;
    try {
      if (!await _requireScreenLock() ||
          !mounted ||
          generation != _generation) {
        return;
      }
      if (!_isScreenProtected) {
        await PrivateContentStore.protectScreen(true);
        _isScreenProtected = true;
      }
      if (useDeviceRecovery) {
        key = await PrivateContentStore.unlockWithDeviceRecovery(
          prompt: resetPassword
              ? l10n.resetPrivatePassword
              : l10n.privateInformation,
        );
        if (key == null) return;
      } else if (isBiometric) {
        key = await PrivateContentStore.unlockWithBiometrics();
        if (key == null) return;
      } else {
        key = await PrivateContentStore.unlockWithPassword(
          password,
          isExisting: _payload.isNotEmpty,
        );
      }
      if (!mounted || generation != _generation) return;
      final value = await PrivateContentStore.decrypt(_payload, key);
      final isPasswordConfigured =
          isPassword ||
          _isPasswordConfigured ||
          await PrivateContentStore.hasPassword();
      final isBiometricEnabled = await PrivateContentStore.hasBiometrics()
          .catchError((Object _) => false);
      if (!isPassword && !await _waitForForeground()) {
        if (mounted && generation == _generation) {
          setState(
            () => _error = l10n.couldNotUnlockPrivateInformationPleaseTryAgain,
          );
        }
        return;
      }
      if (!mounted || generation != _generation) return;
      var recoverySetupFailed = false;
      try {
        await PrivateContentStore.prepareDeviceRecovery(key);
      } catch (error) {
        recoverySetupFailed = true;
        if (kDebugMode) {
          final code = error is PlatformException ? ' (${error.code})' : '';
          debugPrint(
            'Private device recovery setup: ${error.runtimeType}$code',
          );
        }
      }
      final hasDeviceRecovery = await PrivateContentStore.hasDeviceRecovery()
          .catchError((Object _) => false);
      if (!isPassword && !await _waitForForeground()) {
        if (mounted && generation == _generation) {
          setState(
            () => _error = l10n.couldNotUnlockPrivateInformationPleaseTryAgain,
          );
        }
        return;
      }
      // An authentication result must not reveal text after the screen has closed or lost focus
      if (!mounted ||
          generation != _generation ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _key = key;
      key = null;
      final draft = PrivateEntryContent.decode(value);
      _text.text = draft.text;
      _login.text = draft.login;
      _entryPassword.text = draft.password;
      _showCredentials = draft.hasCredentials;
      _showEntryPassword = false;
      if (isCreating) TextInput.finishAutofillContext(shouldSave: true);
      setState(() {
        _isLocked = false;
        _isPasswordConfigured = isPasswordConfigured;
        _isBiometricEnabled = isBiometricEnabled;
        _hasDeviceRecovery = hasDeviceRecovery;
        _isChangingPassword = resetPassword;
        if (recoverySetupFailed) _error = l10n.privateRecoverySetupFailed;
      });
      _restartTimer();
    } catch (error) {
      if (kDebugMode) {
        final action = isCreating ? 'creation' : 'unlock';
        final code = error is PlatformException ? ' (${error.code})' : '';
        debugPrint('Private information $action: ${error.runtimeType}$code');
      }
      if (mounted && generation == _generation) {
        final message = switch (error) {
          PrivateRecoveryFailure.noScreenLock =>
            l10n.screenLockSetupInstructions,
          PrivateRecoveryFailure.missingKey => l10n.screenLockNeedsPriorUnlock,
          PrivateRecoveryFailure.unreadableKey =>
            l10n.privateRecoveryKeyAccessFailed,
          PrivateRecoveryFailure.setup => l10n.privateRecoverySetupFailed,
          PrivateRecoveryFailure.prompt => l10n.couldNotVerifyScreenLock,
          PrivateRecoveryFailure.busy => l10n.privateRecoveryBusy,
          FormatException(message: 'Incorrect private password.') =>
            l10n.incorrectPrivateMergePassword,
          FormatException(
            message: 'Unlock with biometrics first, then add a private password.',
          ) =>
            l10n.unlockWithBiometricsToSetABackupPassword,
          FormatException(
            message: 'The private key is missing. Existing private text cannot be recovered here.',
          ) =>
            l10n.privatePasswordUnavailable,
          _ when isCreating =>
            l10n.couldNotSaveThePrivatePasswordPleaseTryAgain,
          _ when useDeviceRecovery => l10n.privateRecoveryKeyAccessFailed,
          _ when isBiometric =>
            l10n.biometricAccessIsUnavailableOrWasCancelledUseYourPrivatePassword,
          _ => l10n.couldNotUnlockPrivateInformationPleaseTryAgain,
        };
        setState(() => _error = message);
        if (error == PrivateRecoveryFailure.missingKey &&
            _isPasswordConfigured) {
          _passwordFocus.requestFocus();
        }
      }
    } finally {
      key?.destroy();
      if (mounted) {
        _clearPasswordFields();
        setState(() {
          _isWorking = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _lock() async {
    if (_isLocked || _isWorking) return;
    _lockTimer?.cancel();
    final key = _key;
    _key = null;
    final value = _privateDraft;
    _clearPrivateDraft();
    _clearPasswordFields();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLocked = true;
      _isWorking = true;
      _isChangingPassword = false;
    });
    try {
      if (key != null && _isDirty) {
        _payload = await PrivateContentStore.encrypt(value, key);
        if (mounted && widget.embedded) {
          _isDirty = false;
          widget.onDirtyChanged?.call(false);
          widget.onChanged?.call(_payload);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!
                  .couldNotKeepTheLatestPrivateEditPleaseUnlockAndCheckIt,
        );
      }
    } finally {
      key?.destroy();
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<String?> _commitEmbedded() async {
    if (_isWorking) return null;
    if (_isLocked || !_isDirty) return _payload;
    final key = _key;
    if (key == null) return null;
    _lockTimer?.cancel();
    setState(() => _isWorking = true);
    try {
      final payload = await PrivateContentStore.encrypt(_privateDraft, key);
      if (!mounted) return null;
      _payload = payload;
      _isDirty = false;
      widget.onDirtyChanged?.call(false);
      widget.onChanged?.call(payload);
      return payload;
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!
                  .couldNotProtectTheLatestEditPleaseTryAgain,
        );
      }
      return null;
    } finally {
      if (mounted) {
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            !_isLocked) {
          _restartTimer();
        } else {
          _key?.destroy();
          _key = null;
          _clearPrivateDraft();
          _isLocked = true;
        }
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _done() async {
    if (widget.embedded) {
      final payload = await _commitEmbedded();
      if (payload != null && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.privateInformationSaved,
            ),
          ),
        );
      }
      return;
    }
    if (_isWorking) return;
    _lockTimer?.cancel();
    final key = _key;
    _key = null;
    final value = _privateDraft;
    setState(() => _isWorking = true);
    try {
      if (!_isLocked && key != null) {
        _payload = await PrivateContentStore.encrypt(value, key);
      }
      if (!mounted) return;
      _clearPrivateDraft();
      setState(() => _isLeaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, _payload);
      });
    } catch (_) {
      if (mounted) {
        _clearPrivateDraft();
        setState(() {
          _isLocked = true;
          _isWorking = false;
          _error = AppLocalizations.of(context)!
              .couldNotProtectTheLatestEditUnlockToCheckAndTryAgain;
        });
      }
    } finally {
      key?.destroy();
    }
  }

  Future<void> _back() async {
    if (_isWorking || _isAskingToLeave) return;
    _isAskingToLeave = true;
    final isDiscarded = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(AppLocalizations.of(context)!.discardPrivateChanges),
        content: Text(
          AppLocalizations.of(context)!
              .theseChangesHaveNotBeenAddedToTheEntryYet,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.discard),
          ),
        ],
      ),
    );
    _isAskingToLeave = false;
    if (!mounted || isDiscarded != true) return;
    setState(() => _isLeaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_showPassword || _showConfirmation)) {
      setState(() {
        _showPassword = false;
        _showConfirmation = false;
      });
    }
    if (state == AppLifecycleState.resumed) {
      final waiting = _waitingForResume;
      if (waiting != null && !waiting.isCompleted) waiting.complete();
    }
    if (state != AppLifecycleState.resumed && _isAuthenticating && _isLocked) {
      // The system prompt can take focus. Keep the fields locked until the
      // authentication result arrives and this route is in the foreground.
      return;
    }
    if (state != AppLifecycleState.resumed) {
      if (_isWorking) {
        // Hide immediately even while a protected save is completing
        _generation++;
        _clearPasswordFields();
        _clearPrivateDraft();
        setState(() => _isLocked = true);
      } else {
        unawaited(_lock());
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    final waiting = _waitingForResume;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    widget.controller?._commit = null;
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _clearPrivateDraft();
    _text.dispose();
    _login.dispose();
    _entryPassword.dispose();
    _password.clear();
    _passwordFocus.dispose();
    _password.dispose();
    _confirmation.clear();
    _confirmation.dispose();
    _key?.destroy();
    unawaited(
      PrivateContentStore.protectScreen(false).catchError((Object _) {}),
    );
    super.dispose();
  }

  IconButton _passwordVisibilityButton(bool visible, VoidCallback toggle) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: visible
          ? l10n.hidePrivateEntryPassword
          : l10n.showPrivateEntryPassword,
      onPressed: _isReady && !_isWorking ? toggle : null,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }

  Widget _passwordFields({
    required bool creating,
    required VoidCallback submit,
  }) => AutofillGroup(
    onDisposeAction: AutofillContextAction.cancel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (creating) ...[
          Text(
            AppLocalizations.of(context)!.privatePasswordKeepSafe,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _password,
          focusNode: _passwordFocus,
          obscureText: !_showPassword,
          enabled: _isReady && !_isWorking,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          autofillHints: [
            creating ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: InputDecoration(
            labelText: creating
                ? AppLocalizations.of(context)!.newPrivatePassword
                : AppLocalizations.of(context)!.privatePassword,
            helperText: creating
                ? AppLocalizations.of(context)!.useAtLeast6Characters
                : null,
            suffixIcon: _passwordVisibilityButton(
              _showPassword,
              () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          onSubmitted: creating ? null : (_) => submit(),
        ),
        if (creating) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirmation,
            obscureText: !_showConfirmation,
            enabled: _isReady && !_isWorking,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.repeatPrivatePassword,
              suffixIcon: _passwordVisibilityButton(
                _showConfirmation,
                () => setState(() => _showConfirmation = !_showConfirmation),
              ),
            ),
            onSubmitted: (_) => submit(),
          ),
        ],
      ],
    ),
  );
  Future<bool> _requireScreenLock() async {
    if (!PrivateContentStore.supportsBiometrics) return true;
    final l10n = AppLocalizations.of(context)!;
    bool configured;
    try {
      configured = await PrivateContentStore.hasScreenLock();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.couldNotVerifyScreenLock);
      return false;
    }
    if (!mounted) return false;
    if (!configured) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(l10n.setUpScreenLock),
          content: Text(l10n.screenLockSetupInstructions),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(l10n.close),
            ),
            if (defaultTargetPlatform == TargetPlatform.android)
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(l10n.openSettings),
              ),
          ],
        ),
      );
      if (!mounted || open != true) return false;
      try {
        await PrivateContentStore.openScreenLockSettings();
      } on PlatformException {
        if (mounted) setState(() => _error = l10n.screenLockSetupInstructions);
      }
      return false;
    }
    return true;
  }

  Future<void> _useScreenLock({bool resetPassword = false}) {
    if (!resetPassword && !_isPasswordConfigured && _isBiometricEnabled) {
      return _unlock(isBiometric: true);
    }
    return _unlock(useDeviceRecovery: true, resetPassword: resetPassword);
  }

  Future<void> _copyPrivateValue(String value, String confirmation) async {
    if (_isLocked || _isWorking || value.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    var message = confirmation;
    _restartTimer();
    try {
      if (PrivateContentStore.supportsBiometrics) {
        await const MethodChannel('entries/privacy')
            .invokeMethod<void>('copyPrivateValue', value);
      } else {
        await Clipboard.setData(ClipboardData(text: value));
      }
    } catch (_) {
      message = l10n.couldNotCopyPrivateValue;
    }
    if (!mounted || _isLocked) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _copyPrivateValueButton(
    TextEditingController controller,
    String tooltip,
    String confirmation,
  ) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => IconButton(
      tooltip: tooltip,
      onPressed: _isWorking || value.text.isEmpty
          ? null
          : () => _copyPrivateValue(value.text, confirmation),
      icon: const Icon(Icons.content_copy_outlined),
    ),
  );

  Widget _credentialsBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final editable = widget.isEditable;
    if (!_showCredentials) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _isWorking
              ? null
              : () {
                  setState(() => _showCredentials = true);
                  _restartTimer();
                },
          icon: const Icon(Icons.add),
          label: Text(l10n.addPrivateLogin),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.privateLoginAndPassword, style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          if (editable || _login.text.isNotEmpty) ...[
            TextField(
              controller: _login,
              readOnly: !editable,
              enabled: !_isWorking,
              autofillHints: null,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                labelText: l10n.privateLoginLabel,
                suffixIcon: _copyPrivateValueButton(
                  _login,
                  l10n.copyPrivateLogin,
                  l10n.privateLoginCopied,
                ),
              ),
              onChanged: (_) => _markPrivateDraftChanged(),
              onTap: _restartTimer,
            ),
            const SizedBox(height: 12),
          ],
          if (editable || _entryPassword.text.isNotEmpty)
            TextField(
              controller: _entryPassword,
              readOnly: !editable,
              enabled: !_isWorking,
              obscureText: !_showEntryPassword,
              obscuringCharacter: '*',
              enableInteractiveSelection: _showEntryPassword || editable,
              autofillHints: null,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                labelText: l10n.privateEntryPassword,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _copyPrivateValueButton(
                      _entryPassword,
                      l10n.copyPrivatePassword,
                      l10n.privatePasswordCopied,
                    ),
                    IconButton(
                      tooltip: _showEntryPassword
                          ? l10n.hidePrivateEntryPassword
                          : l10n.showPrivateEntryPassword,
                      onPressed: _isWorking
                          ? null
                          : () {
                              setState(
                                () => _showEntryPassword = !_showEntryPassword,
                              );
                              _restartTimer();
                            },
                      icon: Icon(
                        _showEntryPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              onChanged: (_) => _markPrivateDraftChanged(),
              onTap: _restartTimer,
            ),
        ],
      ),
    );
  }

  Widget _fields(BuildContext context) => ListView(
    shrinkWrap: widget.embedded,
    physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
    padding: EdgeInsets.all(widget.embedded ? 12 : 20),
    children: [
      if (_isLocked) ...[
        if (!widget.embedded) ...[
          Icon(
            widget.securitySettings
                ? Icons.shield_outlined
                : Icons.lock_outline_rounded,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.passwordsAndSensitiveText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          _isPasswordConfigured
              ? (_isBiometricEnabled || _hasDeviceRecovery
                    ? AppLocalizations.of(context)!.enterPasswordOrUseScreenLock
                    : AppLocalizations.of(context)!.enterYourPrivatePassword)
              : _isBiometricEnabled
              ? AppLocalizations.of(context)!.enterPasswordOrUseScreenLock
              : _payload.isNotEmpty
              ? AppLocalizations.of(context)!.privatePasswordUnavailable
              : AppLocalizations.of(context)!
                    .createAPasswordToProtectThisSection,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_isPasswordConfigured ||
            (!_isBiometricEnabled && _payload.isEmpty)) ...[
          _passwordFields(
            creating: !_isPasswordConfigured,
            submit: () => _unlock(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isWorking || !_isReady ? null : () => _unlock(),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(
              _isWorking
                  ? AppLocalizations.of(context)!.pleaseWait
                  : _isPasswordConfigured
                  ? PrivateContentStore.supportsBiometrics
                        ? AppLocalizations.of(context)!.enterPassword
                        : AppLocalizations.of(context)!.unlock
                  : AppLocalizations.of(context)!.createPassword,
            ),
          ),
        ],
        if (PrivateContentStore.supportsBiometrics &&
            (_isPasswordConfigured ||
                _hasDeviceRecovery ||
                _isBiometricEnabled))
          OutlinedButton.icon(
            onPressed: _isWorking || !_isReady ? null : () => _useScreenLock(),
            icon: const Icon(Icons.phonelink_lock_outlined),
            label: Text(AppLocalizations.of(context)!.unlock),
          ),
        if (_isPasswordConfigured &&
            PrivateContentStore.supportsBiometrics) ...[
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: _isWorking || !_isReady
                ? null
                : () => _useScreenLock(resetPassword: true),
            child: Text(AppLocalizations.of(context)!.forgotPassword),
          ),
        ],
      ] else ...[
        if (_isChangingPassword || !_isPasswordConfigured) ...[
          Text(
            _isPasswordConfigured
                ? AppLocalizations.of(context)!.setANewPrivatePassword
                : AppLocalizations.of(context)!.addABackupPrivatePassword,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          _passwordFields(creating: true, submit: _savePassword),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isWorking ? null : _savePassword,
            child: Text(AppLocalizations.of(context)!.savePassword),
          ),
          const SizedBox(height: 16),
        ],
        if (!widget.securitySettings && !_isChangingPassword) ...[
          Text(
            widget.isEditable
                ? AppLocalizations.of(
                    context,
                  )!.onlyThisPrivateFieldIsEncryptedTheTitleNormalTextAndAttachmentsRemainVisible
                : AppLocalizations.of(context)!
                      .locksWhenYouLeaveTheAppOrAfter60SecondsOfInactivity,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (widget.isEditable)
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: null,
              maxLength: 4096,
              enabled: !_isWorking,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              enableInteractiveSelection: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!
                    .passwordRecoveryDetailsOrOtherPrivateInformation,
              ),
              onChanged: (_) => _markPrivateDraftChanged(),
              onTap: _restartTimer,
            )
          else if (_text.text.isNotEmpty)
            SelectableText(
              _text.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (_showCredentials || widget.isEditable) ...[
            const SizedBox(height: 16),
            _credentialsBlock(context),
          ],
        ],
        if (widget.securitySettings && !_isChangingPassword) ...[
          if (_isPasswordConfigured && !_isChangingPassword)
            FilledButton.tonalIcon(
              onPressed: _isWorking
                  ? null
                  : () => setState(() => _isChangingPassword = true),
              icon: const Icon(Icons.key_outlined),
              label: Text(AppLocalizations.of(context)!.changePrivatePassword),
            ),
        ],
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (widget.isEditable &&
          !_isChangingPassword &&
          (!_isLocked || _isDirty)) ...[
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isWorking ? null : _done,
          child: Text(AppLocalizations.of(context)!.apply),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!
              .saveTheEntryAfterwardsToKeepTheseChanges,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.embedded) {
      final colors = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.lock_outline, color: colors.primary),
              title: Text(AppLocalizations.of(context)!.privateInformation),
              trailing: !_isLocked || widget.onCollapse != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isLocked)
                          IconButton(
                            tooltip: AppLocalizations.of(context)!.lockNow,
                            onPressed: _isWorking ? null : _lock,
                            icon: const Icon(Icons.lock_outline),
                          ),
                        if (widget.onCollapse case final collapse?)
                          IconButton(
                            tooltip: AppLocalizations.of(context)!.close,
                            onPressed: _isWorking ? null : collapse,
                            icon: const Icon(Icons.expand_less),
                          ),
                      ],
                    )
                  : null,
            ),
            _fields(context),
          ],
        ),
      );
    }
    return PopScope(
      canPop: _isLeaving || (!_isDirty && !_isWorking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isWorking) _back();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            widget.securitySettings
                ? AppLocalizations.of(context)!.security
                : AppLocalizations.of(context)!.privateInformation,
          ),
          actions: [
            if (!_isLocked)
              IconButton(
                tooltip: AppLocalizations.of(context)!.lockNow,
                onPressed: _isWorking ? null : _lock,
                icon: const Icon(Icons.lock_outline),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _fields(context),
            ),
          ),
        ),
      ),
    );
  }
}
