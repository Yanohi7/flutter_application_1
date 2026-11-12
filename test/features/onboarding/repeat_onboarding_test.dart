import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/app.dart';
import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/features/profile/data/profile_store.dart';
import 'package:flutter_application_1/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_categories_repository.dart';
import '../../support/test_entries_repository.dart';

void main() {
  testWidgets('A fresh test launch always opens the introduction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final photo = File('assets/images/spiderman-bg.jpg').readAsBytesSync();
    final profile = _TestProfile();
    addTearDown(profile.dispose);

    for (var launch = 0; launch < 2; launch++) {
      profile.setTestAvatar(photo);
      await tester.pumpWidget(
        MyApp(
          key: ValueKey(launch),
          entriesRepository: TestEntriesRepository(),
          categoriesRepository: TestCategoriesRepository(),
          repeatOnboarding: true,
          profile: profile,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Capture your ideas'), findsOneWidget);
      if (launch == 0) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Give everything a place'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Take your entries with you'), findsOneWidget);
        expect(find.textContaining('Sign in with Google'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Profile'), findsOneWidget);
      final avatar = find.byType(ProfileAvatar);
      expect(
        find.descendant(of: avatar, matching: find.byType(Image)),
        findsOneWidget,
      );
      profile.setTestAvatar(null);
      await tester.pump();
      expect(
        find.descendant(
          of: avatar,
          matching: find.byIcon(Icons.person_outline),
        ),
        findsOneWidget,
      );
    }
  });
}

class _TestProfile extends ProfileStore {
  _TestProfile() : super(DatabaseHelper.instance);

  @override
  Uint8List? avatar;

  void setTestAvatar(Uint8List? bytes) {
    avatar = bytes;
    notifyListeners();
  }
}
