import 'package:flutter/widgets.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

String cloudSyncMessage(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context)!;
  return switch (message) {
    'There are no entries to sync yet.' => l10n.nothingToSync,
    'Entries are up to date.' => l10n.entriesCurrent,
    'Entries uploaded to Google Drive.' => l10n.entriesUploaded,
    'Entries downloaded from Google Drive.' => l10n.entriesDownloaded,
    'Both sets of entries are now synced. See Google Drive copies for imported entries.' =>
      l10n.bothVersionsSynced,
    'Google sign-in was canceled.' => l10n.googleSignInWasCanceled,
    'Could not connect your Google account. Try again.' =>
      l10n.couldNotConnectGoogle,
    'Google took too long to respond. Try again.' => l10n.googleTimeout,
    'Check your internet connection and try again.' => l10n.checkConnection,
    'Could not sync. Your entries are safe on this device.' =>
      l10n.couldNotSync,
    'Choose the Google account for this workspace.' =>
      l10n.chooseWorkspaceGoogleAccount,
    'Some guest entries changed during transfer. Both copies are safe.' =>
      l10n.guestEntriesChangedDuringTransfer,
    'Incorrect private password.' => l10n.incorrectPrivateMergePassword,
    _ => message,
  };
}
