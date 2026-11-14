import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/features/entry/domain/entities/media_attachment.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_photo_gallery.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Swipe and keyboard move between attached photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EntryPhotoGallery(
            photos: [
              MediaAttachment(
                fileType: 'photo',
                fileName: 'First',
                localPath: 'assets/images/google-sign-in-light.png',
              ),
              MediaAttachment(
                fileType: 'photo',
                fileName: 'Second',
                localPath: 'assets/images/google-sign-in-dark.png',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-550, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Close image'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
