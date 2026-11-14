import 'package:flutter_application_1/l10n/app_localizations.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../cloud_sync/presentation/cloud_sync_controller.dart';
import '../../../cloud_sync/presentation/cloud_sync_panel.dart';
import '../../../cloud_sync/presentation/google_account_actions.dart';
import '../../../premium/presentation/pages/premium_page.dart';
import '../../data/profile_store.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_photo_crop.dart';

enum _PhotoAction { change, remove }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;
  CloudSyncController? _sync;
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync = context.read<CloudSyncController?>();
    _userId = context.read<ProfileStore?>()?.userId;
    _sync?.setProfileVisible(ModalRoute.isCurrentOf(context) ?? true);
  }

  @override
  void dispose() {
    if (_sync?.activeUserId == _userId) {
      _sync?.setProfileVisible(false);
    }
    super.dispose();
  }

  Future<void> _openPhoto(ProfileStore profile) async {
    final avatar = profile.avatar;
    if (avatar == null) return;
    final original = profile.originalPath;
    final action = await showDialog<_PhotoAction>(
      context: context,
      builder: (context) => AppDialog(
        title: AppLocalizations.of(context)!.profilePhoto,
        onClose: () => Navigator.pop(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * .48).clamp(
                  140,
                  420,
                ),
                width: double.infinity,
                child: InteractiveViewer(
                  maxScale: 4,
                  child: original == null
                      ? Image.memory(avatar, fit: BoxFit.contain)
                      : Image(
                          image: ResizeImage(
                            FileImage(File(original)),
                            width: 2560,
                            height: 2560,
                            policy: ResizeImagePolicy.fit,
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Image.memory(avatar, fit: BoxFit.contain),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, _PhotoAction.change),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(AppLocalizations.of(context)!.changePhoto),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(context, _PhotoAction.remove),
                  child: Text(AppLocalizations.of(context)!.removePhoto),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _PhotoAction.remove) {
      final confirmed = await confirmPhotoRemoval(
        context,
        title: AppLocalizations.of(context)!.removeProfilePhoto,
        message: AppLocalizations.of(context)!
            .yourProfileWillShowTheDefaultAvatar,
      );
      if (!confirmed || !mounted) return;
    }
    await _changePhoto(profile, remove: action == _PhotoAction.remove);
  }

  Future<void> _changePhoto(ProfileStore profile, {bool remove = false}) async {
    setState(() => _busy = true);
    try {
      if (remove) {
        await profile.setAvatar(null);
        return;
      }
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: AppLocalizations.of(context)!.photos,
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
            uniformTypeIdentifiers: [
              'public.jpeg',
              'public.png',
              'org.webmproject.webp',
            ],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 20 * 1024 * 1024) {
        throw FormatException(
          AppLocalizations.of(context)!.chooseAPhotoSmallerThan20Mb,
        );
      }
      final bytes = await file.readAsBytes();
      final codec = await ui
          .instantiateImageCodecWithSize(
            await ui.ImmutableBuffer.fromUint8List(bytes),
            getTargetSize: (width, height) {
              if (width > 16000 || height > 16000) {
                throw FormatException(
                  AppLocalizations.of(context)!
                      .chooseAPhotoUpTo16000PixelsOnEachSide,
                );
              }
              return width >= height
                  ? ui.TargetImageSize(width: width.clamp(1, 2048))
                  : ui.TargetImageSize(height: height.clamp(1, 2048));
            },
          )
          .onError((error, stack) {
            if (error is FormatException) throw error;
            throw const FormatException(
              'This image could not be opened. Choose a JPG, PNG or WebP image.',
            );
          });
      try {
        final frame = await codec.getNextFrame();
        try {
          if (!mounted) return;
          final crop = await showProfilePhotoCrop(context, frame.image);
          if (crop != null && mounted) {
            await profile.setAvatar(crop, original: bytes);
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : AppLocalizations.of(context)!.couldNotUpdateYourPhoto,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName(ProfileStore profile) async {
    final controller = TextEditingController(text: profile.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.profile),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.editProfileName,
            hintText: profile.isGuest
                ? AppLocalizations.of(context)!.guest
                : (profile.email ?? ''),
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await profile.setName(controller.text.trim());
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appPreferences,
    builder: (context, _) {
      final theme = Theme.of(context);
      final profile = context.watch<ProfileStore?>();
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.profile)),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _busy || _sync == null
                                ? null
                                : () => showWorkspaceAccounts(context, _sync!),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  if (profile?.avatar == null)
                                    const ProfileAvatar(diameter: 56)
                                  else
                                    Tooltip(
                                      message: AppLocalizations.of(context)!
                                          .viewProfilePhoto,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _busy || profile == null
                                            ? null
                                            : () => _openPhoto(profile),
                                        child: const ProfileAvatar(
                                          diameter: 56,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                profile?.name ??
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.guest,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_sync != null) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.arrow_drop_down,
                                                size: 24,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          profile?.isGuest == true
                                              ? AppLocalizations.of(context)!
                                                    .entriesSavedOnThisDevice
                                              : (profile?.email ??
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.googleAccount),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _busy || profile == null
                                    ? null
                                    : () => _editName(profile),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text(
                                  AppLocalizations.of(context)!.editProfileName,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _busy || profile == null
                                    ? null
                                    : () => _changePhoto(profile),
                                icon: Icon(
                                  profile?.avatar == null
                                      ? Icons.add_a_photo_outlined
                                      : Icons.photo_library_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  profile?.avatar == null
                                      ? AppLocalizations.of(context)!
                                            .addProfilePhoto
                                      : AppLocalizations.of(context)!
                                            .changePhoto,
                                ),
                              ),
                            ],
                          ),
                          if (_sync != null && profile?.isGuest != false)
                            const GoogleAccountActions(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CloudSyncPanel(),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.workspace_premium_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        appPreferences.isPremium
                            ? 'Premium'
                            : AppLocalizations.of(context)!.freePlan,
                      ),
                      subtitle: Text(
                        appPreferences.isPremium
                            ? AppLocalizations.of(context)!
                                  .noAdsAllColorThemesUnlocked
                            : AppLocalizations.of(context)!.explorePremium,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showPremiumDialog(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
