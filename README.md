# EntryNote

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local databases

The app uses one SQLite schema for notes, categories, attachments, and related
metadata. A normal installation opens one active file named `entries.db`. On
Windows and Linux this file is in the app's support directory. On mobile the
platform's SQLite directory is used. There is no database server to deploy.

On the first launch after an upgrade, the app checks for the former
`test_database.db`, validates a copy, and opens it as `entries.db`. The old file
is retained as a backup. Close the old version before launching the updated app.
If two legacy copies both contain notes or custom categories, the app stops the
migration rather than guessing which copy to use.

### Populated test database

`test/data/entries_test.db` contains separate English and Ukrainian category
trees with practical notes, recipes, task lists, and vocabulary tables.
Launch **Entries — Test workspace** in VS Code to open this sample data
with working attachments. The personal workspace opens `entries.db`.

To create the test database if it is missing, run:

```sh
flutter test test/tools/build_test_database.dart
```

To replace the generated sample data, add
`--dart-define=REPLACE_TEST_DATABASE=true`.

## Mobile ads

A plain `flutter run` and the test workspace use Google's sample ad units.
On Android, run `flutter run --dart-define=ENTRIES_ADMOB_LIVE=true` to use
your own AdMob units. Mobile release builds use your configured App ID and
ad unit IDs by default.

- Android build defines: `ENTRIES_ADMOB_ANDROID_APP_ID`,
  `ENTRIES_ADMOB_ANDROID_BANNER_ID`, and `ENTRIES_ADMOB_ANDROID_REWARDED_ID`.
  The Android manifest reads the App ID from the same build defines.
- iOS build defines: `ENTRIES_ADMOB_IOS_APP_ID`, `ENTRIES_ADMOB_IOS_BANNER_ID`,
  and `ENTRIES_ADMOB_IOS_REWARDED_ID`. Set the matching App ID in
  `ios/Flutter/AdMob.local.xcconfig` for the iOS release using
  `ENTRIES_ADMOB_APP_ID = your-app-id`.

Supply each build define as `--dart-define=NAME=value`. Configure and publish
the applicable consent messages in AdMob's **Privacy & messaging** section.
Use the test-workspace target to verify rewards before enabling live ads.

Store your Android AdMob IDs in the ignored `entrynote.release.local.json`
at the project root. Explicit
`--dart-define` and `--dart-define-from-file` values take precedence.
Use the platform's own App ID and distinct banner and rewarded IDs from the
same publisher.

## Android release signing

Use the upload key already registered in Play Console if one exists. For a
first release, create an upload keystore in Android Studio and back it up.
Create the ignored file `android/key.properties` locally. On Windows, use
forward slashes in the path.

```properties
storeFile=C:/path/to/entrynote-upload.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
```

Build the bundle with `flutter build appbundle --release` and include the
live build defines when ads are ready. The release build requires the
upload keystore. Keep the keystore and passwords outside source control.
For Google sign-in in a Play-distributed build, register the Android
package name and the **Play app signing certificate SHA-1** in the Google
Cloud project. For a locally installed APK signed with the upload key,
register that certificate SHA-1 as well if you plan to test that APK.

## Google Drive across platforms

Use OAuth clients from the same Google Cloud project and enable the Drive API
in that project. While the OAuth app is in Testing, add the test Google
accounts to its audience. The Android client is configured in Google Cloud
using the Android package and signing certificate, and the app uses the
existing Web client ID during Android sign-in.

- **iPhone and Mac.** Create an iOS-type OAuth client for each target bundle
  identifier as applicable. Put the client ID and reversed URL scheme in
  `ios/Flutter/GoogleOAuth.local.xcconfig` and
  `macos/Runner/Configs/GoogleOAuth.local.xcconfig` respectively.
  Use the settings `ENTRIES_GOOGLE_CLIENT_ID` and
  `ENTRIES_GOOGLE_REVERSED_CLIENT_ID`.
- **Windows and Linux.** Pass `ENTRIES_GOOGLE_DESKTOP_CLIENT_ID` using the
  Desktop OAuth client. If the OAuth client configuration requires its
  installed-app secret, supply `ENTRIES_GOOGLE_DESKTOP_CLIENT_SECRET` in
  the local build defines. The desktop app signs in through the system
  browser and uses a localhost callback. The installed client credential
  is part of the built executable. Never use a Web client secret here.

From Profile, connect Google Drive and select **Sync now**. If both
devices edit offline, open **Review** and choose **Keep both**. Differing
Drive entries and attachments are copied into **Google Drive copies**.
Existing local entries and the local profile are kept. Earlier Drive
revisions are retained. If private information uses different encryption
keys, both versions remain separate until the key conflict is resolved.
