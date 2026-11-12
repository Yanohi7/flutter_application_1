import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/entry/domain/entities/media_attachment.dart';
import 'package:flutter_application_1/features/entry/presentation/entry_playback.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_audio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Inline and mini players control the same session and speed', (
    tester,
  ) async {
    final playback = _TestPlayback();
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<EntryPlayback>.value(
        value: playback,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const EntryMiniPlayer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(
                          appBar: null,
                          body: EntryAudioPlayer(attachments: [_track]),
                        ),
                      ),
                    ),
                    child: const Text('Open entry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play audio'));
    await tester.pump();
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    for (final speed in ['0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×']) {
      expect(find.text(speed), findsWidgets);
    }
    await tester.tap(find.text('1.25×').last);
    await tester.pumpAndSettle();
    expect(playback.speed, 1.25);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Recording'), findsOneWidget);
    expect(find.byTooltip('Pause audio'), findsOneWidget);
    expect(find.text('1.25×'), findsOneWidget);
    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.75×').last);
    await tester.pumpAndSettle();
    expect(playback.speed, 0.75);
    await tester.tap(find.byTooltip('Close player'));
    await tester.pumpAndSettle();
    expect(find.text('Recording'), findsNothing);
  });
}

const _track = MediaAttachment(
  fileType: 'audio',
  fileName: 'Recording',
  localPath: 'recording',
);

class _TestPlayback extends EntryPlayback {
  MediaAttachment? _active;
  bool _playing = false;
  double _rate = 1;

  @override
  MediaAttachment? get track => _active;
  @override
  bool get isPlaying => _playing;
  @override
  double get speed => _rate;
  @override
  Duration get duration => const Duration(minutes: 2);

  @override
  Future<bool> toggle(MediaAttachment attachment) async {
    _active = attachment;
    _playing = !_playing;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setSpeed(double value) async {
    _rate = value;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> stop() async {
    _active = null;
    _playing = false;
    notifyListeners();
    return true;
  }
}
