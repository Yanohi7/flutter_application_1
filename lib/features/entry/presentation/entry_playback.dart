import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../domain/entities/media_attachment.dart';

/// Owns one playback session across entry routes.
class EntryPlayback extends ChangeNotifier {
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  final position = ValueNotifier(Duration.zero);
  final _subscriptions = <StreamSubscription<dynamic>>[];
  AudioPlayer? _player;
  Future<bool>? _operation;
  ({String path, Completer<void> released})? _source;
  MediaAttachment? _track;
  Duration _duration = Duration.zero;
  double _speed = 1;
  bool _disposed = false;

  MediaAttachment? get track => _track;
  Duration get duration => _duration;
  double get speed => _speed;
  bool get isPlaying => _player?.state == PlayerState.playing;
  bool get isBusy => _operation != null;

  AudioPlayer _openPlayer() {
    final player = AudioPlayer();
    player.positionUpdater = TimerPositionUpdater(
      getPosition: player.getCurrentPosition,
      interval: const Duration(milliseconds: 150),
    );
    _subscriptions.addAll([
      player.onDurationChanged.listen((value) {
        if (_disposed || _track == null || _duration == value) return;
        _duration = value;
        notifyListeners();
      }),
      player.onPositionChanged.listen((value) {
        if (!_disposed && _track != null) position.value = value;
      }),
      player.onPlayerStateChanged.listen((_) {
        if (!_disposed) notifyListeners();
      }),
      player.onPlayerComplete.listen((_) {
        final source = _source;
        if (_disposed || source == null) return;
        _clearTrack();
        unawaited(_releaseCompletedSource(source.released));
      }),
    ]);
    return player;
  }

  Future<bool> toggle(MediaAttachment attachment) => _perform(() async {
    final player = _player ??= _openPlayer();
    if (_track?.localPath == attachment.localPath) {
      if (isPlaying) {
        await player.pause();
      } else {
        await player.resume();
        await player.setPlaybackRate(_speed);
      }
      return;
    }
    if (_source != null) {
      await player.release();
      _releaseSource();
    }
    _source = (path: attachment.localPath, released: Completer<void>());
    _track = attachment;
    _duration = Duration.zero;
    if (!_disposed) {
      position.value = Duration.zero;
      notifyListeners();
    }
    try {
      await player.play(DeviceFileSource(attachment.localPath));
    } catch (_) {
      _clearTrack();
      try {
        await player.release();
      } finally {
        _releaseSource();
      }
      rethrow;
    }
    if (_speed != 1) await player.setPlaybackRate(_speed);
  });

  Future<bool> seek(Duration target) => _perform(() async {
    if (_track == null || _duration == Duration.zero) return;
    await _player!.seek(target);
    if (!_disposed && _track != null) position.value = target;
  });

  Future<bool> setSpeed(double value) => _perform(() async {
    if (_track == null || !speeds.contains(value) || _speed == value) return;
    await _player!.setPlaybackRate(value);
    _speed = value;
  });

  Future<void> pause() async {
    await _operation;
    if (!_disposed && isPlaying) await _perform(() => _player!.pause());
  }

  Future<bool> stop() => _perform(() async {
    await _player?.release();
    _releaseSource();
    _clearTrack();
  });

  Future<void> stopIfPath(String path) async {
    await _operation;
    if (!_disposed && _track?.localPath == path) await stop();
  }

  void updateTrack(String previousPath, MediaAttachment saved) {
    if (_disposed || _track?.localPath != previousPath) return;
    _track = saved;
    notifyListeners();
  }

  Future<void> waitForSourceIn(String directory) async {
    final source = _source;
    if (source != null && path.isWithin(directory, source.path)) {
      await source.released.future;
    }
  }

  Future<void> _releaseCompletedSource(Completer<void> released) async {
    await _operation;
    if (_disposed || _source?.released != released || _track != null) return;
    await stop();
  }

  void _releaseSource() {
    final source = _source;
    _source = null;
    source?.released.complete();
  }

  Future<bool> _perform(Future<void> Function() action) {
    if (_disposed || isBusy) return Future.value(true);
    // Schedule the operation after registering it, including synchronous failures.
    final operation = Future<void>.microtask(action)
        .then((_) => true, onError: (Object _) => false)
        .whenComplete(() {
          _operation = null;
          if (!_disposed) notifyListeners();
        });
    _operation = operation;
    notifyListeners();
    return operation;
  }

  void _clearTrack() {
    _track = null;
    _duration = Duration.zero;
    if (!_disposed) {
      position.value = Duration.zero;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final player = _player;
    if (player != null) {
      unawaited(
        Future<void>(() async {
          await _operation;
          try {
            await player.dispose();
          } catch (error) {
            debugPrint(
              'Could not dispose audio playback: ${error.runtimeType}',
            );
          } finally {
            _releaseSource();
          }
        }),
      );
    }
    position.dispose();
    super.dispose();
  }
}
