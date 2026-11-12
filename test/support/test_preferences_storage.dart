import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestPreferencesStorage extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  final _state = _StorageState();
  bool get failWrite => _state.failWrite;
  set failWrite(bool value) => _state.failWrite = value;
  Completer<void>? get pendingWrite => _state.pendingWrite;
  set pendingWrite(Completer<void>? value) => _state.pendingWrite = value;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (pendingWrite != null) await pendingWrite!.future;
    if (failWrite) throw StateError('Storage unavailable');
    values[key] = value;
  }
}

class _StorageState {
  bool failWrite = false;
  Completer<void>? pendingWrite;
}
