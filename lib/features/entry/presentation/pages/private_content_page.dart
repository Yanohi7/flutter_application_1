// Keep decrypted private text in a short-lived authenticated screen and return only ciphertext

import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/security/private_content_store.dart';
import 'private_recovery_files.dart';

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
    this.onChanged,
    this.onDirtyChanged,
    this.controller,
  });
  final String payload;
  final bool isEditable;
  final bool embedded;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onDirtyChanged;
  final PrivateContentEditorController? controller;
  @override
  State<PrivateContentPage> createState() => _PrivateContentPageState();
}

enum _SetupStep { biometrics, recovery }

enum _PasswordRecovery { device, biometrics, file }

class _PrivateContentPageState extends State<PrivateContentPage>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmation = TextEditingController();
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
  bool _isExporting = false;
  bool _recoveryExported = false;
  bool _isChangingPassword = false;
  bool _offerRecoveryAfterBiometrics = false;
  bool _offerBiometricsAfterReset = false;
  bool _setupAfterPassword = false;
  Completer<void>? _waitingForResume;
  _SetupStep? _setupStep;
  int _generation = 0;
  String? _error;

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
      final isBiometric = await PrivateContentStore.hasBiometrics();
      final hasDeviceRecovery = await PrivateContentStore.hasDeviceRecovery();
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
          () => _error = 'Private storage is unavailable on this device.',
        );
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (_key == null || _isWorking) return;
    _lockTimer?.cancel();
    setState(() {
      _isWorking = true;
      _isAuthenticating = true;
    });
    try {
      if (value) {
        final isEnabled = await PrivateContentStore.enableBiometrics(_key!);
        if (!isEnabled) return;
        if (mounted) {
          setState(() {
            _isBiometricEnabled = isEnabled;
            if (_setupStep == _SetupStep.biometrics) {
              _setupStep = _offerRecoveryAfterBiometrics
                  ? _SetupStep.recovery
                  : null;
            }
            _error = null;
          });
        }
      } else {
        await PrivateContentStore.disableBiometrics();
        if (mounted) setState(() => _isBiometricEnabled = false);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : 'Biometrics could not be set up. Check your device settings or try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _isAuthenticating = false;
        });
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          await _lock();
        } else {
          _restartTimer();
        }
      }
    }
  }

  Future<void> _savePassword() async {
    if (_isWorking || _key == null) return;
    if (_password.text.length < PrivateContentStore.minimumPasswordLength ||
        _password.text != _confirmation.text) {
      setState(
        () => _error =
            'Use at least 12 characters and enter the same password twice.',
      );
      return;
    }
    _lockTimer?.cancel();
    final key = _key!;
    final value = widget.isEditable && _isDirty ? _text.text : null;
    final password = _password.text;
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
          _isChangingPassword = false;
          if (!_isLocked && _offerBiometricsAfterReset) {
            _setupStep = _SetupStep.biometrics;
          }
          _offerBiometricsAfterReset = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not save the private password. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        _password.clear();
        _confirmation.clear();
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

  Future<void> _unlock({
    bool isBiometric = false,
    bool useRecoveryFile = false,
    bool useDeviceRecovery = false,
    bool resetPassword = false,
    bool setupBiometrics = false,
  }) async {
    if (_isWorking || !_isReady) return;
    final isPassword = !isBiometric && !useRecoveryFile && !useDeviceRecovery;
    final isCreating = isPassword && !_isPasswordConfigured;
    if (isCreating &&
        (_password.text.length < PrivateContentStore.minimumPasswordLength ||
            _password.text != _confirmation.text)) {
      setState(
        () => _error =
            'Use at least 12 characters and enter the same password twice.',
      );
      return;
    }
    final generation = ++_generation;
    setState(() {
      _isWorking = true;
      _isAuthenticating = !isPassword;
      _error = null;
    });
    SecretKeyData? key;
    try {
      if (!_isScreenProtected) {
        await PrivateContentStore.protectScreen(true);
        _isScreenProtected = true;
      }
      if (useDeviceRecovery) {
        key = await PrivateContentStore.unlockWithDeviceRecovery();
        if (key == null) return;
        if (!mounted) return;
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          // The system credential activity can return before Flutter regains focus.
          final resume = _waitingForResume = Completer<void>();
          await resume.future.timeout(
            const Duration(seconds: 1),
            onTimeout: () {},
          );
          _waitingForResume = null;
        }
      } else if (useRecoveryFile) {
        final file = await PrivateRecoveryFiles.pick();
        if (file == null) return;
        try {
          key = await PrivateContentStore.unlockWithRecoveryFile(
            file,
            payload: _payload,
          );
        } finally {
          file.fillRange(0, file.length, 0);
        }
      } else if (isBiometric) {
        key = await PrivateContentStore.unlockWithBiometrics();
        if (key == null) {
          throw const FormatException(
            'Biometrics are unavailable. Unlock with your private password to set them up again.',
          );
        }
      } else {
        key = await PrivateContentStore.unlockWithPassword(
          _password.text,
          isExisting: _payload.isNotEmpty,
        );
      }
      final value = await PrivateContentStore.decrypt(_payload, key);
      if (!useDeviceRecovery) {
        await PrivateContentStore.prepareDeviceRecovery(key);
      }
      final isPasswordConfigured = await PrivateContentStore.hasPassword();
      final isBiometricEnabled = await PrivateContentStore.hasBiometrics();
      final hasDeviceRecovery = await PrivateContentStore.hasDeviceRecovery();
      // An authentication result must not reveal text after the screen has closed or lost focus
      if (!mounted ||
          generation != _generation ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _key = key;
      key = null;
      _text.text = value;
      if (isCreating) TextInput.finishAutofillContext(shouldSave: true);
      setState(() {
        _isLocked = false;
        _isPasswordConfigured = isPasswordConfigured;
        _isBiometricEnabled = isBiometricEnabled;
        _hasDeviceRecovery = hasDeviceRecovery;
        _isChangingPassword = useRecoveryFile || resetPassword;
        _offerRecoveryAfterBiometrics = isCreating;
        _offerBiometricsAfterReset = useDeviceRecovery && !isBiometricEnabled;
        if (isCreating) {
          _setupStep = PrivateContentStore.supportsBiometrics
              ? _SetupStep.biometrics
              : _SetupStep.recovery;
        } else if (setupBiometrics || (isPassword && _setupAfterPassword)) {
          _setupStep = _SetupStep.biometrics;
        } else if (resetPassword || useRecoveryFile) {
          _setupStep = null;
        }
        _setupAfterPassword = false;
      });
      _restartTimer();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : isBiometric
              ? 'Biometric access is unavailable or was cancelled. Use your private password.'
              : useRecoveryFile
              ? 'This file could not unlock the private information.'
              : useDeviceRecovery
              ? 'Device recovery is unavailable. Try your recovery file.'
              : 'Could not unlock private information. Please try again.',
        );
      }
    } finally {
      key?.destroy();
      if (mounted) {
        _password.clear();
        _confirmation.clear();
        setState(() {
          _isWorking = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _exportRecovery(
    BuildContext buttonContext, {
    bool share = false,
  }) async {
    final key = _key;
    if (key == null || _isExporting || _isWorking) return;
    final box = buttonContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final isSetup = _setupStep == _SetupStep.recovery;
    if (isSetup) {
      // The setup step contains no plaintext while the system sheet is open.
      _lockTimer?.cancel();
      _isAuthenticating = true;
    }
    setState(() {
      _isExporting = true;
      _error = null;
    });
    Uint8List? bytes;
    try {
      bytes = await PrivateContentStore.exportRecoveryFile(key);
      if (!mounted || _isLocked || _key != key) return;
      final saved = share
          ? await PrivateRecoveryFiles.share(bytes, origin)
          : await PrivateRecoveryFiles.save(bytes);
      if (mounted && saved) {
        setState(() => _recoveryExported = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              share ? 'Recovery file shared.' : 'Recovery file saved.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not export the recovery file. Try again.',
        );
      }
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted) {
        setState(() => _isExporting = false);
        if (isSetup) {
          _isAuthenticating = false;
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
            _restartTimer();
          } else {
            await _lock();
          }
        }
      }
    }
  }

  Future<void> _lock() async {
    if (_isLocked || _isWorking) return;
    _lockTimer?.cancel();
    final key = _key;
    _key = null;
    final value = _text.text;
    _text.clear();
    _password.clear();
    _confirmation.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLocked = true;
      _isWorking = true;
      _isChangingPassword = false;
    });
    try {
      if (key != null && widget.isEditable) {
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
          () => _error = 'Could not keep the latest private edit. Please unlock and check it.',
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
      final payload = await PrivateContentStore.encrypt(_text.text, key);
      if (!mounted) return null;
      _payload = payload;
      _isDirty = false;
      widget.onDirtyChanged?.call(false);
      widget.onChanged?.call(payload);
      return payload;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not protect the latest edit. Please try again.',
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
          _text.clear();
          _isLocked = true;
        }
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _done() async {
    if (widget.embedded) {
      await _commitEmbedded();
      return;
    }
    if (_isWorking) return;
    _lockTimer?.cancel();
    final key = _key;
    _key = null;
    final value = _text.text;
    setState(() => _isWorking = true);
    try {
      if (!_isLocked && key != null) {
        _payload = await PrivateContentStore.encrypt(value, key);
      }
      if (!mounted) return;
      _text.clear();
      setState(() => _isLeaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, _payload);
      });
    } catch (_) {
      if (mounted) {
        _text.clear();
        setState(() {
          _isLocked = true;
          _isWorking = false;
          _error = 'Could not protect the latest edit. Unlock to check and try again.';
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
        title: const Text('Discard private changes?'),
        content: const Text(
          'These changes have not been added to the entry yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
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
    if (state == AppLifecycleState.resumed) {
      final waiting = _waitingForResume;
      if (waiting != null && !waiting.isCompleted) waiting.complete();
    }
    if (state != AppLifecycleState.resumed && !_isAuthenticating) {
      if (_isWorking) {
        // Hide immediately even while a protected save is completing
        _generation++;
        _password.clear();
        _confirmation.clear();
        _text.clear();
        setState(() => _isLocked = true);
      } else {
        unawaited(_lock());
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.controller?._commit = null;
    _lockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _text.clear();
    _text.dispose();
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

  Widget _passwordFields({
    required bool creating,
    required VoidCallback submit,
  }) => AutofillGroup(
    onDisposeAction: AutofillContextAction.cancel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _password,
          focusNode: _passwordFocus,
          obscureText: true,
          enabled: _isReady && !_isWorking,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          autofillHints: [
            creating ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: InputDecoration(
            labelText: creating ? 'New private password' : 'Private password',
            helperText: creating ? 'Use at least 12 characters.' : null,
          ),
          onSubmitted: creating ? null : (_) => submit(),
        ),
        if (creating) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirmation,
            obscureText: true,
            enabled: _isReady && !_isWorking,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Repeat private password',
            ),
            onSubmitted: (_) => submit(),
          ),
        ],
      ],
    ),
  );

  Widget _recoveryActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'This file can unlock your private information. Keep a copy somewhere separate from this device and your EntryNote backup.',
      ),
      const SizedBox(height: 12),
      Builder(
        builder: (context) => OutlinedButton.icon(
          onPressed: _isWorking || _isExporting
              ? null
              : () => _exportRecovery(context),
          icon: const Icon(Icons.save_alt),
          label: const Text('Save recovery file'),
        ),
      ),
      if (PrivateRecoveryFiles.canShare)
        Builder(
          builder: (context) => OutlinedButton.icon(
            onPressed: _isWorking || _isExporting
                ? null
                : () => _exportRecovery(context, share: true),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share recovery file'),
          ),
        ),
    ],
  );

  void _continueSetup() {
    setState(() {
      _setupStep =
          _setupStep == _SetupStep.biometrics && _offerRecoveryAfterBiometrics
          ? _SetupStep.recovery
          : null;
      _error = null;
    });
    _restartTimer();
  }

  Future<void> _forgotPassword() async {
    final method = await showDialog<_PasswordRecovery>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Reset private password'),
        content: Text(
          _hasDeviceRecovery
              ? 'Confirm your phone’s screen lock to set a new password.'
              : _isBiometricEnabled
              ? 'Use biometrics or your recovery file to set a new password.'
              : 'Use your recovery file to set a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, _PasswordRecovery.file),
            child: const Text('Use recovery file'),
          ),
          if (_isBiometricEnabled)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialog, _PasswordRecovery.biometrics),
              child: const Text('Use biometrics'),
            ),
          if (_hasDeviceRecovery)
            FilledButton(
              onPressed: () => Navigator.pop(dialog, _PasswordRecovery.device),
              child: const Text('Use screen lock'),
            ),
        ],
      ),
    );
    if (!mounted || method == null) return;
    await _unlock(
      isBiometric: method == _PasswordRecovery.biometrics,
      useRecoveryFile: method == _PasswordRecovery.file,
      useDeviceRecovery: method == _PasswordRecovery.device,
      resetPassword: true,
    );
  }

  Future<void> _setUpBiometrics() async {
    if (_isPasswordConfigured && _password.text.isNotEmpty) {
      await _unlock(setupBiometrics: true);
      return;
    }
    final recovery = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Set up biometrics'),
        content: const Text(
          'Unlock with your private password or recovery file first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Enter password'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Use recovery file'),
          ),
        ],
      ),
    );
    if (!mounted || recovery == null) return;
    if (recovery) {
      await _unlock(useRecoveryFile: true, setupBiometrics: true);
    } else {
      _setupAfterPassword = true;
      _passwordFocus.requestFocus();
    }
  }

  Widget _fields(BuildContext context) => ListView(
    shrinkWrap: widget.embedded,
    physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
    padding: EdgeInsets.all(widget.embedded ? 12 : 20),
    children: [
      if (_isLocked) ...[
        const Icon(Icons.lock_outline_rounded, size: 40),
        const SizedBox(height: 16),
        const Text('Passwords and sensitive text', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          _isPasswordConfigured
              ? (_isBiometricEnabled
                    ? 'Enter your private password or use biometrics.'
                    : 'Enter your private password.')
              : _isBiometricEnabled
              ? 'Unlock with biometrics to set a backup password.'
              : _payload.isNotEmpty
              ? 'Use your recovery file to unlock this restored entry.'
              : 'Create a password to protect this section.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_isPasswordConfigured ||
            (!_isBiometricEnabled && _payload.isEmpty)) ...[
          if (!_isPasswordConfigured &&
              PrivateContentStore.supportsBiometrics) ...[
            const Text(
              'A screen lock lets you reset this password on this phone.',
            ),
            const SizedBox(height: 8),
          ],
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
                  ? 'Please wait…'
                  : _isPasswordConfigured
                  ? 'Unlock'
                  : 'Create password',
            ),
          ),
        ],
        if (_isBiometricEnabled)
          OutlinedButton.icon(
            onPressed: _isWorking || !_isReady
                ? null
                : () => _unlock(isBiometric: true),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Unlock with biometrics'),
          ),
        if (!_isBiometricEnabled &&
            _isPasswordConfigured &&
            PrivateContentStore.supportsBiometrics)
          OutlinedButton.icon(
            onPressed: _isWorking || !_isReady ? null : _setUpBiometrics,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Set up biometrics'),
          ),
        if (_isPasswordConfigured || _isBiometricEnabled)
          TextButton(
            onPressed: _isWorking || !_isReady ? null : _forgotPassword,
            child: const Text('Forgot password?'),
          )
        else if (_payload.isNotEmpty)
          TextButton(
            onPressed: _isWorking || !_isReady
                ? null
                : () => _unlock(useRecoveryFile: true),
            child: const Text('Use a recovery file'),
          ),
      ] else if (_setupStep == _SetupStep.biometrics) ...[
        const Icon(Icons.fingerprint, size: 40),
        const SizedBox(height: 12),
        const Text('Set up biometric unlock', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Use the fingerprint or face recognition configured on this device for everyday access.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isWorking ? null : () => _toggleBiometrics(true),
          child: const Text('Enable biometrics'),
        ),
        TextButton(
          onPressed: _isWorking ? null : _continueSetup,
          child: const Text('Skip'),
        ),
      ] else if (_setupStep == _SetupStep.recovery) ...[
        const Icon(Icons.key_outlined, size: 40),
        const SizedBox(height: 12),
        const Text('Save a recovery key', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        _recoveryActions(),
        TextButton(
          onPressed: _isWorking || _isExporting ? null : _continueSetup,
          child: Text(_recoveryExported ? 'Continue' : 'Skip for now'),
        ),
      ] else ...[
        if (_isChangingPassword || !_isPasswordConfigured) ...[
          Text(
            _isPasswordConfigured
                ? 'Set a new private password'
                : 'Add a backup private password',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _passwordFields(creating: true, submit: _savePassword),
          FilledButton(
            onPressed: _isWorking ? null : _savePassword,
            child: const Text('Save password'),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          widget.isEditable
              ? 'Only this private field is encrypted. The title, normal text and attachments remain visible.'
              : 'Locks when you leave the app or after 60 seconds of inactivity.',
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
            decoration: const InputDecoration(
              hintText:
                  'Password, recovery details or other private information',
            ),
            onChanged: (_) {
              setState(() => _isDirty = true);
              widget.onDirtyChanged?.call(true);
              _restartTimer();
            },
            onTap: _restartTimer,
          )
        else
          SelectableText(
            _text.text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        if (_isPasswordConfigured && !_isChangingPassword)
          TextButton(
            onPressed: _isWorking
                ? null
                : () => setState(() => _isChangingPassword = true),
            child: const Text('Change private password'),
          ),
        if (PrivateContentStore.supportsBiometrics)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use biometrics'),
            subtitle: const Text(
              'Unlock with your fingerprint or face recognition on this device.',
            ),
            value: _isBiometricEnabled,
            onChanged: _isWorking ? null : _toggleBiometrics,
          ),
        if (_isPasswordConfigured)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Recovery file'),
            leading: const Icon(Icons.key_outlined),
            children: [_recoveryActions()],
          ),
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
          _setupStep == null &&
          (!_isLocked || _isDirty)) ...[
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isWorking ? null : _done,
          child: const Text('Use private information'),
        ),
        const SizedBox(height: 8),
        Text(
          'Save the entry afterwards to keep these changes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      final colors = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.lock_outline, color: colors.primary),
              title: const Text('Private information'),
              trailing: !_isLocked
                  ? IconButton(
                      tooltip: 'Lock now',
                      onPressed: _isWorking ? null : _lock,
                      icon: const Icon(Icons.lock_outline),
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
        appBar: AppBar(
          title: const Text('Private information'),
          actions: [
            if (!_isLocked)
              IconButton(
                tooltip: 'Lock now',
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
