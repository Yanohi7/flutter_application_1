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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync = context.read<CloudSyncController?>();
    _sync?.setProfileVisible(ModalRoute.isCurrentOf(context) ?? true);
  }

  @override
  void dispose() {
    _sync?.setProfileVisible(false);
    super.dispose();
  }

  Future<void> _openPhoto(ProfileStore profile) async {
    final avatar = profile.avatar;
    if (avatar == null) {
      await _changePhoto(profile);
      return;
    }
    final original = profile.originalPath;
    final action = await showDialog<_PhotoAction>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Profile photo',
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
                  label: const Text('Change photo'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(context, _PhotoAction.remove),
                  child: const Text('Remove photo'),
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
        title: 'Remove profile photo?',
        message: 'Your profile will show the default avatar.',
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
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Photos',
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
        throw const FormatException('Choose a photo smaller than 20 MB.');
      }
      final bytes = await file.readAsBytes();
      final codec = await ui
          .instantiateImageCodecWithSize(
            await ui.ImmutableBuffer.fromUint8List(bytes),
            getTargetSize: (width, height) {
              if (width > 16000 || height > 16000) {
                throw const FormatException(
                  'Choose a photo up to 16,000 pixels on each side.',
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
                  : 'Could not update your photo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appPreferences,
    builder: (context, _) {
      final theme = Theme.of(context);
      final profile = context.watch<ProfileStore?>();
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
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
                          Row(
                            children: [
                              Tooltip(
                                message: profile?.avatar == null
                                    ? 'Add profile photo'
                                    : 'View profile photo',
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _busy || profile == null
                                      ? null
                                      : () => _openPhoto(profile),
                                  child: const ProfileAvatar(diameter: 56),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile?.name ?? 'Guest',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Entries saved on this device',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                        appPreferences.isPremium ? 'Premium' : 'Free plan',
                      ),
                      subtitle: Text(
                        appPreferences.isPremium
                            ? 'No ads · All color themes unlocked'
                            : 'Explore Premium',
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
