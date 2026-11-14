// Start Flutter, initialize desktop SQLite and configure the application window

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/ads/mobile_ads_service.dart';
import 'core/database/database_helper.dart';
import 'core/presentation/app_preferences.dart';
import 'core/security/private_content_store.dart';
import 'features/cloud_sync/data/datasources/google_account_remote_datasource.dart';
import 'features/cloud_sync/presentation/cloud_sync_controller.dart';
import 'features/profile/data/profile_store.dart';

// Export MyApp for the code to work if other classes import main
export 'app/app.dart' show MyApp;

Future<void> main() => startEntries();

Future<void> startEntries({
  Future<DatabaseHelper> Function()? prepareWorkspace,
  bool repeatOnboarding = false,
  String? testWorkspaceNamespace,
}) async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for using plugins/native code before runApp
  entriesAds.configure(testAds: kDebugMode || testWorkspaceNamespace != null);
  PrivateContentStore.workspaceNamespace = testWorkspaceNamespace;
  await appPreferences.load(
    key: testWorkspaceNamespace == null
        ? AppPreferences.storageKey
        : '${AppPreferences.storageKey}_$testWorkspaceNamespace',
    allowPremiumPreview:
        entriesAds.rewardedId == null && entriesAds.bannerId == null,
  );
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit(); // Initialize SQLite for the desktop application
    // Use the desktop SQLite implementation for subsequent database requests
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 700),
      minimumSize: Size(280, 600),
      center: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final database =
      await (prepareWorkspace?.call() ?? Future.value(DatabaseHelper.instance));
  if (await GoogleAccountRemoteDataSource.isSupported()) {
    final sync = CloudSyncController(
      database,
      testWorkspace: testWorkspaceNamespace != null,
      testWorkspaceName: testWorkspaceNamespace,
    );
    try {
      await sync.load();
      runApp(
        ListenableBuilder(
          listenable: sync.workspaceRevision,
          builder: (_, _) => MyApp(
            key: ValueKey(sync.activeUserId),
            database: sync.activeDatabase,
            profile: sync.profile,
            cloudSync: sync,
            repeatOnboarding: repeatOnboarding,
          ),
        ),
      );
      sync.scheduleInitialSync();
      return;
    } catch (error) {
      sync.dispose();
      debugPrint('Could not initialize Google Drive: ${error.runtimeType}');
    }
  }
  final profile = kIsWeb ? null : ProfileStore(database);
  try {
    await profile?.load();
  } catch (error) {
    debugPrint('Could not load the local profile: $error');
  }
  runApp(
    MyApp(
      database: database,
      profile: profile,
      repeatOnboarding: repeatOnboarding,
    ),
  );
}
