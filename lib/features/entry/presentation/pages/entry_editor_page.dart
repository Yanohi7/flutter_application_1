import '../../../category/presentation/pages/category_create_page.dart';
// Edit an entry draft, choose its category and return the saved result to the calling page

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ads/mobile_ads_service.dart';
import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_ui.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/datetime_helpers.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/entry_audio_input.dart';
import '../../data/datasources/entry_photo_storage.dart';
import '../../domain/entities/entry.dart';
import '../../domain/entities/media_attachment.dart';
import '../cubit/entry_cubit.dart';
import '../cubit/entry_state.dart';
import '../entry_playback.dart';
import '../../../category/presentation/cubit/category_cubit.dart';
import '../../../category/presentation/cubit/category_state.dart';
import '../../../category/presentation/widgets/category_picker.dart';
import '../widgets/entry_audio_player.dart';
import '../widgets/entry_file_list.dart';
import '../widgets/entry_document_editor.dart';
import '../widgets/entry_formatted_content.dart';
import '../widgets/private_content_tile.dart';
import 'private_content_page.dart';
import '../../data/datasources/entry_file_input.dart';
import '../widgets/attachment_name_dialog.dart';
import '../widgets/entry_recording_panel.dart';
import '../widgets/entry_photo_gallery.dart';

/// Entry == null creates an entry; otherwise open the saved entry
class EntryEditorPage extends StatefulWidget {
  final Entry? entry;
  const EntryEditorPage({super.key, this.entry, this.onActions});
  final Future<void> Function(Entry entry)? onActions;
  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  final _formKey = GlobalKey<FormState>(); // Provides access to validate()
  late final TextEditingController _title;
  late final EntryDocumentController _content;
  late final EntryPlayback _playback;
  final _textDirty = ValueNotifier(false);
  final _privateController = PrivateContentEditorController();
  String _lastTitle = '';

  late bool _isPinned;
  late bool _isFavorite;
  ({int id, String name})? _category;
  // Remember the starting category once so later choices can be detected as unsaved changes
  int? _initialCategoryId;
  Entry? _original;
  bool _reading = false;
  bool _allowPop = false; // Allow leaving after saving or confirming
  bool _askingToLeave =
      false; // Prevent multiple leave-confirmation dialogs from opening at once
  String? _saveError; // An error does not clear the text controllers

  final _imagePicker = ImagePicker();
  final _audioInput = EntryAudioInput();
  final _draftAudios = <XFile>[];
  final _attachmentLabels = <String, String>{};
  bool _isChangingAudio = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  final _recordingClock = Stopwatch();
  Timer? _recordingTimer;
  StreamSubscription? _amplitudeSubscription;
  final _levels = <double>[];
  final _recordingFrame = ValueNotifier(0);

  Future<void> _pauseRecording() async {
    if (_isChangingAudio) return;
    setState(() => _isChangingAudio = true);
    try {
      if (_isRecordingPaused) {
        await _audioInput.recorder.resume();
        _recordingClock.start();
      } else {
        await _audioInput.recorder.pause();
        _recordingClock.stop();
      }
      if (mounted) setState(() => _isRecordingPaused = !_isRecordingPaused);
    } catch (_) {
      if (mounted) _showMessage('Could not pause or resume the recording.');
    } finally {
      if (mounted) setState(() => _isChangingAudio = false);
    }
  }

  bool get _isAudioBusy => _isChangingAudio || _isRecording;

  Future<void> _changeAudio({required bool isRecordingAction}) async {
    if (_isChangingAudio ||
        _isPreparingSave ||
        _isPickingAttachment ||
        context.read<EntryCubit>().state.isSaving) {
      return;
    }
    setState(() => _isChangingAudio = true);
    try {
      if (isRecordingAction && !_isRecording) {
        await _playback.pause();
        if (!mounted) return;
        final isStarted = await _audioInput.startRecording();
        if (!mounted) return;
        setState(() {
          _isRecording = isStarted;
          _isRecordingPaused = false;
        });
        if (isStarted) {
          _levels.clear();
          await _amplitudeSubscription?.cancel();
          _amplitudeSubscription = _audioInput.recorder
              .onAmplitudeChanged(const Duration(milliseconds: 150))
              .listen((amplitude) {
                if (!mounted || _isRecordingPaused) return;
                _levels.add(((amplitude.current + 60) / 60).clamp(0.0, 1.0));
                if (_levels.length > 40) _levels.removeAt(0);
              }, onError: (Object _) {});

          _recordingClock
            ..reset()
            ..start();
          _recordingTimer?.cancel();
          _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (
            _,
          ) {
            if (mounted && !_isRecordingPaused) _recordingFrame.value++;
          });
        }
        if (!isStarted) _showMessage('Microphone permission was denied.');
      } else {
        final audio = isRecordingAction
            ? await _audioInput.stopRecording()
            : await _audioInput.pickAudio();
        if (!mounted) return;
        if (isRecordingAction) {
          unawaited(_amplitudeSubscription?.cancel());
          _amplitudeSubscription = null;
          setState(() {
            _isRecording = false;
            _isRecordingPaused = false;
            _recordingClock.stop();
            _recordingTimer?.cancel();
          });
        }
        if (audio != null &&
            !_hasAttachment(audio.path) &&
            await _allowAttachment() &&
            mounted) {
          setState(() {
            _draftAudios.add(audio);
            if (isRecordingAction) {
              _attachmentLabels[audio.path] =
                  'Voice recording ${_retainedAttachments.where((file) => file.fileType == 'audio').length + _draftAudios.length}';
            }
          });
        }
      }
    } on UnsupportedError catch (error) {
      if (mounted) _showMessage(error.message ?? 'Audio is unavailable.');
    } catch (_) {
      if (mounted) _showMessage('Could not complete the audio action.');
    } finally {
      if (mounted) setState(() => _isChangingAudio = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  final _photoStorage = const EntryPhotoStorage();
  bool _isPreparingSave = false;
  final _draftImages = <XFile>[];
  final _draftDocuments = <XFile>[];
  final _documentSizes = <String, int>{};
  late String _privateContent;
  bool _privateDraftDirty = false;
  final _removedPaths = <String>{};
  List<MediaAttachment> get _retainedAttachments =>
      (_original?.attachments ?? const <MediaAttachment>[])
          .where((file) => !_removedPaths.contains(file.localPath))
          .map(_labelled)
          .toList();
  bool _isPickingAttachment =
      false; // Prevent multiple image pickers from opening at once

  bool _hasAttachment(String path) =>
      _retainedAttachments.any((item) => item.localPath == path) ||
      _draftImages.any((item) => item.path == path) ||
      _draftAudios.any((item) => item.path == path) ||
      _draftDocuments.any((item) => item.path == path);

  Future<bool> _allowAttachment() async {
    final count =
        _retainedAttachments.length +
        _draftImages.length +
        _draftAudios.length +
        _draftDocuments.length;
    if (count == 0 ||
        appPreferences.isPremium ||
        entriesAds.rewardedId == null) {
      return true;
    }
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Add another attachment'),
        content: const Text(
          'The first attachment is free. Complete one ad to add this attachment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Watch ad'),
          ),
        ],
      ),
    );
    if (!mounted || agreed != true) return false;
    final result = await entriesAds.showRewarded(
      canShow: () => mounted && ModalRoute.isCurrentOf(context) == true,
    );
    if (!mounted) return false;
    if (result == RewardedAdResult.earned) return true;
    _showMessage(
      result == RewardedAdResult.dismissed
          ? 'Finish the ad to add this attachment.'
          : 'An ad is unavailable right now. Try again later.',
    );
    return false;
  }

  // Store draft labels by source path and apply them to copied files only on Save
  MediaAttachment _labelled(MediaAttachment file) =>
      _attachmentLabels.containsKey(file.localPath)
      ? file.withDisplayName(_attachmentLabels[file.localPath]!)
      : file;

  List<MediaAttachment> get _photos => [
    ..._retainedAttachments.where((file) => file.fileType == 'photo'),
    for (final file in _draftImages)
      _labelled(
        MediaAttachment(
          fileType: 'photo',
          fileName: file.name,
          localPath: file.path,
        ),
      ),
  ];
  List<MediaAttachment> get _audios => [
    ..._retainedAttachments.where((file) => file.fileType == 'audio'),
    for (final file in _draftAudios)
      _labelled(
        MediaAttachment(
          fileType: 'audio',
          fileName: file.name,
          localPath: file.path,
        ),
      ),
  ];

  List<MediaAttachment> get _documents => [
    ..._retainedAttachments.where(
      (file) => const ['document', 'video'].contains(file.fileType),
    ),
    for (final file in _draftDocuments)
      MediaAttachment(
        fileType: EntryFileInput.attachmentType(file.name),
        fileName: file.name,
        localPath: file.path,
        fileSize: _documentSizes[file.path],
      ),
  ];

  Future<void> _pickDocuments() async {
    if (_isPickingAttachment || _isPreparingSave || _isAudioBusy) return;
    setState(() => _isPickingAttachment = true);
    try {
      final selected = await EntryFileInput.pick();
      final skipped = <String>[];
      for (final file in selected) {
        if (!mounted) return;
        if (_hasAttachment(file.path)) continue;
        try {
          await EntryFileInput.validate(file.path, file.name);
          final size = await file.length();
          if (!mounted || !await _allowAttachment() || !mounted) break;
          setState(() {
            _documentSizes[file.path] = size;
            _draftDocuments.add(file);
          });
        } on FormatException {
          skipped.add(file.name);
        }
      }
      if (!mounted) return;
      if (skipped.isNotEmpty) {
        _showMessage(
          'Some files were skipped. Use supported files up to 10 MB each.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not read the selected files. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isPickingAttachment = false);
    }
  }

  Future<void> _renameAttachment(MediaAttachment file) async {
    final isPhoto = file.fileType == 'photo';
    final name = await showAttachmentNameDialog(
      context,
      name: isPhoto ? file.displayName ?? '' : file.audioTitle,
      isPhoto: isPhoto,
    );
    if (!mounted || name == null) return;
    setState(() => _attachmentLabels[file.localPath] = name);
  }

  bool _isRemovingMedia = false;
  Future<void> _removeMedia(MediaAttachment file) async {
    if (_isRemovingMedia ||
        _isPreparingSave ||
        context.read<EntryCubit>().state.isSaving) {
      return;
    }
    _isRemovingMedia = true;
    final isPhoto = file.fileType == 'photo';
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isPhoto
              ? 'Remove image?'
              : file.fileType == 'audio'
              ? 'Remove audio?'
              : 'Remove file?',
        ),
        content: Text(
          'This attachment will be removed from the entry when you save.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || isConfirmed != true) {
      _isRemovingMedia = false;
      return;
    }
    if (file.fileType == 'audio') {
      await _playback.stopIfPath(file.localPath);
    }
    _isRemovingMedia = false;
    if (!mounted) return;
    setState(() {
      if (_original?.attachments.any(
            (saved) => saved.localPath == file.localPath,
          ) ??
          false) {
        _removedPaths.add(file.localPath);
      } else {
        _draftImages.removeWhere((draft) => draft.path == file.localPath);
        _draftAudios.removeWhere((draft) => draft.path == file.localPath);
        _draftDocuments.removeWhere((draft) => draft.path == file.localPath);
      }
      _attachmentLabels.remove(file.localPath);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingAttachment || _isPreparingSave || _isAudioBusy) return;

    setState(() => _isPickingAttachment = true);

    try {
      final images = source == ImageSource.gallery
          ? await _imagePicker.pickMultiImage()
          : [?(await _imagePicker.pickImage(source: source))];
      for (final image in images) {
        if (!mounted) return;
        if (_hasAttachment(image.path)) continue;
        if (!await _allowAttachment() || !mounted) break;
        setState(() => _draftImages.add(image));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to pick an image. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingAttachment = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _playback = context.read<EntryPlayback>();
    _original = widget.entry;
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _content = EntryDocumentController(text: widget.entry?.content ?? '');
    _lastTitle = _title.text;
    _privateContent = widget.entry?.privateContent ?? '';
    _isPinned = widget.entry?.isPinned ?? false;
    _isFavorite = widget.entry?.isFavorite ?? false;
    final original = widget.entry;

    if (original != null) {
      _category = (id: original.categoryId, name: original.categoryName);
    } else {
      final categoryState = context.read<CategoryCubit>().state;

      for (final category in categoryState.categories) {
        if (category.id == categoryState.selectedCategoryId) {
          _category = (id: category.id, name: category.name);
          break;
        }

        if (category.isDefault) {
          _category = (id: category.id, name: category.name);
        }
      }
    }

    _initialCategoryId = _category?.id;
    _title.addListener(_onTitleChanged);
    _content.addListener(_onDraftChanged);
  }

  @override
  void didUpdateWidget(covariant EntryEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = widget.entry;
    if (live == null || identical(oldWidget.entry, live)) return;
    if (_category?.id == _initialCategoryId) {
      _category = (id: live.categoryId, name: live.categoryName);
    }
    _initialCategoryId = live.categoryId;
    _original = live;
  }

  void _onTitleChanged() {
    if (_lastTitle == _title.text) return;
    _lastTitle = _title.text;
    _onDraftChanged();
  }

  void _onDraftChanged() {
    _textDirty.value =
        _title.text != (_original?.title ?? '') || _content.isDirty;
    if (_saveError != null) setState(() => _saveError = null);
  }

  bool get _isDirty =>
      _privateDraftDirty ||
      _draftImages.isNotEmpty ||
      _draftDocuments.isNotEmpty ||
      _privateContent != (_original?.privateContent ?? '') ||
      _removedPaths.isNotEmpty ||
      _draftAudios.isNotEmpty ||
      _attachmentLabels.isNotEmpty ||
      _textDirty.value ||
      (_original == null && (_isPinned || _isFavorite)) ||
      _category?.id != _initialCategoryId;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_amplitudeSubscription?.cancel());
    _recordingClock.stop();
    _title.dispose(); // Also removes the registered listeners
    _content.dispose();
    _textDirty.dispose();
    _recordingFrame.dispose();
    for (final audio in _draftAudios) {
      unawaited(_playback.stopIfPath(audio.path));
    }
    unawaited(_audioInput.dispose(beforeCleanup: _playback.waitForSourceIn));

    super.dispose();
  }

  // Change the form draft only, leaving the stored entry unchanged until Save
  Future<void> _chooseCategory() async {
    if (context.read<EntryCubit>().state.isSaving) return;

    final cubit = context.read<CategoryCubit>();

    if (cubit.state.isSaving) return;

    if (cubit.state.status != CategoryStatus.success) {
      await cubit.loadCategories();
    }

    if (!mounted) return;

    if (cubit.state.status != CategoryStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categories are not ready. Please try again.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final selection = await showCategoryPicker(
      onCreateCategory: (_) => showCategoryEditor(context),
      context: context,
      categories: cubit.state.categories,
      selectedId: _category?.id,

      // An entry must belong to a real category, unlike a category that can have no parent
      allowTopLevel: false,
      title: 'Select a category',
    );

    final selected = selection?.category;

    if (!mounted || selected == null) return;

    setState(() {
      _category = (id: selected.id, name: selected.name);
      _saveError = null; // Clear any previous save error when changing category
    });
  }

  Future<bool> _save() async {
    final cubit = context.read<EntryCubit>();
    if (_isPreparingSave ||
        _isPickingAttachment ||
        _isAudioBusy ||
        cubit.state.isWriting) {
      return false;
    }
    if (!_reading) {
      final valid = _formKey.currentState?.validate() ?? false;
      if (!valid) return false;
      if (_title.text.trim().isEmpty) {
        _showMessage('Enter an entry title');
        return false;
      }
    }
    setState(() => _isPreparingSave = true);
    try {
      return await _persist(cubit);
    } finally {
      if (mounted) setState(() => _isPreparingSave = false);
    }
  }

  Future<bool> _persist(EntryCubit cubit) async {
    if (_privateController.isAttached) {
      final payload = await _privateController.commit();
      if (!mounted) return false;
      if (payload == null) {
        _showMessage('Finish unlocking or saving private information first.');
        return false;
      }
      _privateContent = payload;
    }
    FocusScope.of(context).unfocus(); // Dismiss the keyboard
    final attachments = <MediaAttachment>[];
    final drafts = [
      for (final photo in _draftImages) (type: 'photo', file: photo),
      for (final file in _draftDocuments)
        (type: EntryFileInput.attachmentType(file.name), file: file),
      for (final audio in _draftAudios) (type: 'audio', file: audio),
    ];
    if (drafts.isNotEmpty) {
      try {
        for (final draft in drafts) {
          final copied = await _photoStorage.copyAttachment(
            draft.file.path,
            draft.file.name,
            fileType: draft.type,
          );
          attachments.add(
            copied.withDisplayName(_attachmentLabels[draft.file.path] ?? ''),
          );
        }
      } catch (_) {
        await _removeCopiedAttachments(attachments);
        if (mounted) {
          setState(() {
            _saveError = 'Could not save the attachments. Please try again.';
          });
        }
        return false;
      }
      if (!mounted) {
        await _removeCopiedAttachments(attachments);
        return false;
      }
    }

    final saved = await cubit.saveEntry(
      original: _original,
      title: _title.text,
      content: _content.text,
      isPinned: _original?.isPinned ?? _isPinned,
      isFavorite: _original?.isFavorite ?? _isFavorite,
      category: _category,
      newAttachments: attachments,
      retainedAttachments: _retainedAttachments,
      privateContent: _privateContent,
      attachmentsOnly: _reading,
    );
    if (saved == null) await _removeCopiedAttachments(attachments);
    if (!mounted) return false;
    if (saved == null) {
      setState(
        () => _saveError = cubit.state.errorMessage ?? 'Please try again.',
      );
      return false;
    }
    for (final (index, draft) in drafts.indexed) {
      if (draft.type == 'audio') {
        _playback.updateTrack(draft.file.path, attachments[index]);
      }
    }
    final playing = _playback.track;
    if (playing != null) {
      final savedTrack = saved.attachments
          .where((file) => file.localPath == playing.localPath)
          .firstOrNull;
      if (savedTrack != null) {
        _playback.updateTrack(playing.localPath, savedTrack);
      }
    }
    if (widget.entry != null) {
      setState(() {
        _original = saved;
        _category = (id: saved.categoryId, name: saved.categoryName);
        _initialCategoryId = saved.categoryId;
        _privateDraftDirty = false;
        _draftImages.clear();
        _draftAudios.clear();
        _draftDocuments.clear();
        _documentSizes.clear();
        _removedPaths.clear();
        _attachmentLabels.clear();
        _saveError = null;
      });
      final savedTitle = saved.title ?? '';
      if (_title.text != savedTitle) _title.text = savedTitle;
      _content.markSaved(saved.content);
      return true;
    }
    setState(() => _allowPop = true);
    // Wait for PopScope to rebuild before closing the page programmatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context)
            .pop(saved); // Return the saved entry to the caller
      }
    });
    return true;
  }

  Future<void> _toggleReading() async {
    if (!_reading && _isDirty && !await _save()) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _reading = !_reading);
  }

  Future<void> _openActions() async {
    final original = _original;
    if (original != null && !_isPreparingSave) {
      await widget.onActions?.call(original);
    }
  }

  Future<void> _changeMark(Entry entry, {required bool favorite}) async {
    final cubit = context.read<EntryCubit>();
    if (_isPreparingSave || cubit.state.isWriting) return;
    await (favorite ? cubit.toggleFavorite(entry) : cubit.togglePin(entry));
    final error = cubit.state.errorMessage;
    if (mounted && error != null) _showMessage(error);
  }

  Future<void> _removeCopiedAttachments(
    List<MediaAttachment> attachments,
  ) async {
    for (final attachment in attachments) {
      await _photoStorage.removeAttachment(
        attachment.localPath,
        fileType: attachment.fileType,
      );
    }
  }

  Future<void> _confirmLeave() async {
    if (_isAudioBusy) return;
    if (_askingToLeave ||
        _isPreparingSave ||
        _isPickingAttachment ||
        context.read<EntryCubit>().state.isSaving) {
      return;
    }
    _askingToLeave = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'If you leave now, your changes will not be saved.',
        ),
        actions: [
          TextButton(
            // The tap handler; null disables the button
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            // The tap handler; null disables the button
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    _askingToLeave = false;
    if (!mounted || discard != true) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _category?.name ?? 'Default';
    final original = _original;
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return BlocBuilder<EntryCubit, EntryState>(
      buildWhen: (before, after) => before.isSaving != after.isSaving,
      builder: (context, state) => AbsorbPointer(
        absorbing: _isPreparingSave,
        child: ValueListenableBuilder<bool>(
          valueListenable: _textDirty,
          builder: (context, _, child) => PopScope(
            canPop:
                !state.isSaving &&
                !_isPreparingSave &&
                !_isPickingAttachment &&
                !_isAudioBusy &&
                (_allowPop || !_isDirty),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _confirmLeave();
            },
            child: child!,
          ),
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: () {
                  if (state.isSaving ||
                      _isPreparingSave ||
                      _isPickingAttachment ||
                      _isAudioBusy) {
                    return;
                  }
                  if (_isDirty) {
                    _confirmLeave();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: original == null ? const Text('Add entry') : null,
              actions: original == null
                  ? null
                  : [
                      ValueListenableBuilder<bool>(
                        valueListenable: _textDirty,
                        builder: (context, _, _) => Visibility(
                          visible: _isDirty,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: IconButton(
                            tooltip: 'Save changes',
                            icon: const Icon(Icons.check),
                            onPressed:
                                state.isSaving ||
                                    _isPickingAttachment ||
                                    _isAudioBusy
                                ? null
                                : _save,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _reading
                            ? 'Exit reading mode'
                            : 'Reading mode',
                        isSelected: _reading,
                        icon: const Icon(Icons.visibility_outlined),
                        selectedIcon: const Icon(Icons.visibility),
                        onPressed:
                            state.isSaving ||
                                _isPickingAttachment ||
                                _isAudioBusy
                            ? null
                            : _toggleReading,
                      ),
                      IconButton(
                        tooltip: original.isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        icon: Icon(
                          original.isFavorite ? Icons.star : Icons.star_border,
                          color: original.isFavorite
                              ? AppColors.favorite
                              : null,
                        ),
                        onPressed: state.isSaving
                            ? null
                            : () => _changeMark(original, favorite: true),
                      ),
                      IconButton(
                        tooltip: original.isPinned ? 'Unpin' : 'Pin',
                        icon: Icon(
                          original.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: original.isPinned ? AppColors.pin : null,
                        ),
                        onPressed: state.isSaving
                            ? null
                            : () => _changeMark(original, favorite: false),
                      ),
                      if (widget.onActions != null)
                        IconButton(
                          tooltip: 'Entry actions',
                          icon: const Icon(Icons.more_vert),
                          onPressed:
                              state.isSaving ||
                                  _isPickingAttachment ||
                                  _isAudioBusy
                              ? null
                              : _openActions,
                        ),
                    ],
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (original == null)
                          ReadablePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const FieldLabel('Category'),
                                InkWell(
                                  onTap: state.isSaving
                                      ? null
                                      : _chooseCategory,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      suffixIcon: Icon(Icons.arrow_drop_down),
                                    ),
                                    child: Text(location),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          WallpaperTextSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_reading)
                                  SelectableText(
                                    original.title ?? 'Untitled',
                                    style: titleStyle,
                                  )
                                else
                                  EntryTitleField(
                                    controller: _title,
                                    enabled:
                                        !state.isSaving && !_isPreparingSave,
                                    style: titleStyle,
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _reading
                                      ? Text(
                                          location,
                                          style: theme.textTheme.bodySmall,
                                        )
                                      : TextButton.icon(
                                          onPressed: state.isSaving
                                              ? null
                                              : _chooseCategory,
                                          icon: const Icon(
                                            Icons.folder_outlined,
                                            size: 16,
                                          ),
                                          label: Text(location),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            alignment: Alignment.centerLeft,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (_reading) ...[
                          ReadablePanel(
                            child: _content.text.isEmpty
                                ? const Text('No text yet')
                                : EntryDocumentView(content: _content.text),
                          ),
                          if (_privateContent.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            PrivateContentTile(payload: _privateContent),
                          ],
                        ] else
                          EntryDocumentEditor(
                            title: original == null ? _title : null,
                            content: _content,
                            enabled: !state.isSaving && !_isPreparingSave,
                            hasPrivateContent: _privateContent.isNotEmpty,
                            onClosePrivate: () async {
                              if (!_privateController.isAttached) return true;
                              final payload = await _privateController.commit();
                              if (!mounted || payload == null) return false;
                              setState(() => _privateContent = payload);
                              return true;
                            },
                            privatePanel: PrivateContentPage(
                              payload: _privateContent,
                              isEditable: true,
                              embedded: true,
                              controller: _privateController,
                              onDirtyChanged: (value) {
                                if (mounted) {
                                  setState(() => _privateDraftDirty = value);
                                }
                              },
                              onChanged: (value) {
                                if (mounted) {
                                  setState(() => _privateContent = value);
                                }
                              },
                            ),
                          ),

                        const SizedBox(height: 16),
                        ReadablePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const FieldLabel('Images'),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed:
                                        state.isSaving || _isPickingAttachment
                                        ? null
                                        : () => _pickImage(ImageSource.gallery),
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                    label: const Text('Gallery'),
                                  ),
                                  if (defaultTargetPlatform ==
                                      TargetPlatform.android)
                                    OutlinedButton.icon(
                                      onPressed:
                                          state.isSaving || _isPickingAttachment
                                          ? null
                                          : () =>
                                                _pickImage(ImageSource.camera),
                                      icon: const Icon(
                                        Icons.camera_alt_outlined,
                                      ),
                                      label: const Text('Camera'),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              EntryPhotoGallery(
                                photos: _photos,
                                isEnabled:
                                    !state.isSaving &&
                                    !_isPreparingSave &&
                                    !_isPickingAttachment &&
                                    !_isAudioBusy,
                                onCaption: _reading
                                    ? null
                                    : (index) =>
                                          _renameAttachment(_photos[index]),
                                onRemove: _reading
                                    ? null
                                    : (index) => _removeMedia(_photos[index]),
                              ),
                              const SizedBox(height: 20),
                              const FieldLabel('Audio'),
                              if (_isRecording)
                                ValueListenableBuilder<int>(
                                  valueListenable: _recordingFrame,
                                  builder: (context, _, _) =>
                                      EntryRecordingPanel(
                                        elapsed: _recordingClock.elapsed,
                                        levels: _levels,
                                        isPaused: _isRecordingPaused,
                                        isBusy: _isChangingAudio,
                                        onPause: _pauseRecording,
                                        onStop: () => _changeAudio(
                                          isRecordingAction: true,
                                        ),
                                      ),
                                )
                              else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed:
                                          state.isSaving ||
                                              _isAudioBusy ||
                                              _isPreparingSave ||
                                              _isPickingAttachment
                                          ? null
                                          : () => _changeAudio(
                                              isRecordingAction: true,
                                            ),
                                      icon: const Icon(
                                        Icons.mic_none_rounded,
                                        size: 20,
                                      ),
                                      label: const Text('Record'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          state.isSaving ||
                                              _isAudioBusy ||
                                              _isPreparingSave ||
                                              _isPickingAttachment
                                          ? null
                                          : () => _changeAudio(
                                              isRecordingAction: false,
                                            ),
                                      icon: const Icon(
                                        Icons.audio_file_outlined,
                                        size: 20,
                                      ),
                                      label: const Text('Add audio'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                EntryAudioPlayer(
                                  attachments: _audios,
                                  isEnabled:
                                      !state.isSaving &&
                                      !_isPreparingSave &&
                                      !_isAudioBusy,
                                  onRename: _reading ? null : _renameAttachment,
                                  onRemove: _reading ? null : _removeMedia,
                                ),
                              ],
                              const SizedBox(height: 20),
                              const FieldLabel('Files'),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      state.isSaving ||
                                          _isPreparingSave ||
                                          _isAudioBusy ||
                                          _isPickingAttachment
                                      ? null
                                      : _pickDocuments,
                                  icon: const Icon(Icons.attach_file, size: 20),
                                  label: const Text('Add files'),
                                ),
                              ),
                              Text(
                                'Documents, ZIP and video · Up to 10 MB each',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              EntryFileList(
                                files: _documents,
                                onRemove: _reading ? null : _removeMedia,
                                isEnabled:
                                    !state.isSaving &&
                                    !_isPreparingSave &&
                                    !_isAudioBusy &&
                                    !_isPickingAttachment,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (original == null)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => setState(
                                          () => _isFavorite = !_isFavorite,
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: BorderSide(
                                      color: _isFavorite
                                          ? AppColors.favorite
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  icon: Icon(
                                    _isFavorite
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: AppColors.favorite,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _isFavorite ? 'Favorited' : 'Favorite',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => setState(
                                          () => _isPinned = !_isPinned,
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: BorderSide(
                                      color: _isPinned
                                          ? AppColors.pin
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  icon: Icon(
                                    _isPinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined,
                                    color: AppColors.pin,
                                    size: 20,
                                  ),
                                  label: Text(_isPinned ? 'Pinned' : 'Pin'),
                                ),
                              ),
                            ],
                          ),
                        if (_saveError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ReadablePanel(
                              child: Text(
                                _saveError!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        if (original == null) ...[
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: state.isSaving ? null : _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(state.isSaving ? 'Saving…' : 'Save'),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Created ${formatEntryDate(original.createdAt)} · Edited ${formatEntryDate(original.updatedAt)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
