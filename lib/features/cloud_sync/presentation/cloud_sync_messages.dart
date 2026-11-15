import 'package:flutter/widgets.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

String cloudSyncMessage(
  BuildContext context,
  String message, {
  String? fallback,
}) {
  final l10n = AppLocalizations.of(context)!;
  return switch (message) {
    'There are no entries to sync yet.' => l10n.nothingToSync,
    'Entries are up to date.' => l10n.entriesCurrent,
    'Entries uploaded to Google Drive.' => l10n.entriesUploaded,
    'Entries downloaded from Google Drive.' => l10n.entriesDownloaded,
    'Both sets of entries are now synced. See Google Drive copies for imported entries.' =>
      l10n.bothVersionsSynced,
    'Google sign-in was canceled.' => l10n.googleSignInWasCanceled,
    'Google sign-in was canceled or denied.' =>
      l10n.googleSignInCanceledOrDenied,
    'Could not open the browser for Google sign-in.' =>
      l10n.googleSignInBrowserFailed,
    'Could not connect your Google account. Try again.' =>
      l10n.couldNotConnectGoogle,
    'Google could not complete sign-in. Check the Desktop OAuth client configuration.' =>
      l10n.couldNotConnectGoogle,
    'Could not read your Google account. Reconnect and try again.' =>
      l10n.couldNotReadGoogleAccount,
    'Google took too long to respond. Try again.' => l10n.googleTimeout,
    'Check your internet connection and try again.' => l10n.checkConnection,
    'Could not sync. Your entries are safe on this device.' =>
      l10n.couldNotSync,
    'Choose the Google account for this workspace.' =>
      l10n.chooseWorkspaceGoogleAccount,
    'Sign in with Google first.' => l10n.googleSignInRequired,
    'Google Drive access expired. Reconnect your Google account.' =>
      l10n.googleDriveAccessExpired,
    'Google Drive access is required. Reconnect and allow access.' ||
    'Google Drive access is required. Please reconnect.' =>
      l10n.googleDrivePermissionRequired,
    'Google Drive denied access. Check the app permissions and Drive API setup.' =>
      l10n.googleDriveAccessDenied,
    'Google Drive is temporarily unavailable. Try again.' =>
      l10n.googleDriveTemporarilyUnavailable,
    'The previous Drive backup is missing. Your local entries are still on this device.' =>
      l10n.googleDriveBackupMissing,
    'The Google Drive backup did not pass verification.' ||
    'A Drive copy did not pass verification.' =>
      l10n.googleDriveBackupVerificationFailed,
    'An Entries file in Google Drive could not be read.' =>
      l10n.googleDriveBackupUnreadable,
    'The backup is missing its protected private information key.' =>
      l10n.googleDriveBackupKeyMissing,
    'Google Drive returned an invalid upload session.' =>
      l10n.googleDriveUploadFailed,
    'Return to Profile or All Entries and retry the download.' =>
      l10n.googleDriveDownloadRetry,
    'A version changed. Run Sync now to review the latest copies.' ||
    'Entries changed during sync. Try again.' =>
      l10n.googleDriveVersionsChanged,
    'Too many Drive versions to consolidate safely.' =>
      l10n.googleDriveTooManyVersions,
    'This workspace version cannot be merged.' =>
      l10n.googleDriveIncompatibleVersion,
    'This workspace already contains local data.' =>
      l10n.googleDriveWorkspaceNotEmpty,
    'The private information on these copies uses different passwords.' ||
    'This device uses a different private information key.' =>
      l10n.googleDriveDifferentPrivatePasswords,
    'Set a private information password before syncing private entries.' =>
      l10n.googleDrivePrivatePasswordRequired,
    'Some guest entries changed during transfer. Both copies are safe.' ||
    'The guest workspace changed during transfer. Both copies are safe.' =>
      l10n.guestEntriesChangedDuringTransfer,
    'This device and Google Drive have different versions. Both copies were kept.' =>
      l10n.differentVersionsFound,
    'Incorrect private password.' => l10n.incorrectPrivateMergePassword,
    'Set up a screen lock in your phone settings.' =>
      l10n.screenLockSetupInstructions,
    'Could not verify your screen lock. Try again.' =>
      l10n.couldNotVerifyScreenLock,
    'Device recovery is not set up for these entries.' =>
      l10n.screenLockNeedsPriorUnlock,
    'Could not open the protected key on this device.' =>
      l10n.privateRecoveryKeyAccessFailed,
    'Could not set up system unlock on this device.' =>
      l10n.privateRecoverySetupFailed,
    'System verification is already in progress.' => l10n.privateRecoveryBusy,
    'Could not move guest entries. Try again.' => l10n.couldNotMoveGuestEntries,
    'Set a private password in Guest before moving private entries.' =>
      l10n.setGuestPrivatePasswordBeforeTransfer,
    _ => fallback ?? l10n.couldNotSync,
  };
}
