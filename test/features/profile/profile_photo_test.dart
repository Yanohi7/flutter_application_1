import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/features/profile/data/profile_store.dart';
import 'package:flutter_application_1/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter_application_1/features/profile/presentation/widgets/profile_photo_crop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Crop preview keeps the image alive until the dialog closes', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(600, 350);
    picture.dispose();
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showProfilePhotoCrop(context, image);
                image.dispose();
                closed = true;
              },
              child: const Text('Open crop'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open crop'));
    await tester.pumpAndSettle();
    expect(find.text('Adjust profile photo'), findsOneWidget);
    expect(find.byType(RawImage), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(closed, isFalse);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The avatar opens the viewer and removal requires confirmation', (
    tester,
  ) async {
    final photo = File('assets/images/spiderman-bg.jpg').readAsBytesSync();
    final profile = _TestProfile(photo);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileStore?>.value(
        value: profile,
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    expect(find.text('Remove photo'), findsNothing);
    await tester.tap(find.byTooltip('View profile photo'));
    await tester.pumpAndSettle();
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.text('Remove profile photo?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(profile.avatar, photo);
    await tester.tap(find.byTooltip('View profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(profile.avatar, isNull);
    expect(find.byTooltip('Add profile photo'), findsOneWidget);
  });
}

class _TestProfile extends ProfileStore {
  _TestProfile(this.avatar) : super(DatabaseHelper.instance);

  @override
  Uint8List? avatar;

  @override
  Future<void> setAvatar(Uint8List? bytes, {Uint8List? original}) async {
    avatar = bytes;
    notifyListeners();
  }
}
