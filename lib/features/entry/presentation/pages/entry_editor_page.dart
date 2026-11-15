import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/features/category/presentation/category_display_name.dart';

import '../../../category/presentation/pages/category_create_page.dart';

// Edit an entry draft, choose its category and return the saved result to the calling page
import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io' show FileSystemException;

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
  final _titleFieldKey = GlobalKey();
  final _titleFocus = FocusNode();
  final _editorScroll = ScrollController();
  late final TextEditingController _title;
  late final EntryDocumentController _content;
  late final EntryPlayback _playback;
  final _textDirty = ValueNotifier(false);
  final _privateController = PrivateContentEditorController();
  bool _privateOpen = false;
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
      if (mounted)
        _showMessage(
          AppLocalizations.of(context)!.couldNotPauseOrResumeTheRecording,
        );
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
        if (!mounted) return;
        if (!isStarted) {
          _showMessage(
            AppLocalizations.of(context)!.microphonePermissionWasDenied,
          );
        }
      } else {
        final audio = isRecordingAction
            ? await _finishRecording()
            : await _audioInput.pickAudio();
        if (!mounted) return;
        if (isRecordingAction && audio == null) {
          _showMessage(
            AppLocalizations.of(context)!.couldNotCompleteTheAudioAction,
          );
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
      if (mounted) {
        _showMessage(
          error.message ?? AppLocalizations.of(context)!.audioIsUnavailable,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context)!.couldNotCompleteTheAudioAction,
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingAudio = false);
    }
  }

  Future<XFile?> _finishRecording() async {
    try {
      return await _audioInput.stopRecording();
    } finally {
      if (mounted) {
        unawaited(_amplitudeSubscription?.cancel());
        _amplitudeSubscription = null;
        _recordingClock.stop();
        _recordingTimer?.cancel();
        setState(() {
          _isRecording = false;
          _isRecordingPaused = false;
        });
      }
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
        scrollable: true,
        title: Text(AppLocalizations.of(context)!.addAnotherAttachment),
        content: Text(
          AppLocalizations.of(context)!
              .theFirstAttachmentIsFreeCompleteOneAdToAddThisAttachment,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(AppLocalizations.of(context)!.watchAd),
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
          ? AppLocalizations.of(context)!.finishTheAdToAddThisAttachment
          : AppLocalizations.of(context)!
                .anAdIsUnavailableRightNowTryAgainLater,
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
    var pickedFiles = <XFile>[];
    try {
      final selected = await EntryFileInput.pick();
      pickedFiles = selected.files;
      var skipped = selected.skipped;
      var unreadable = selected.unreadable;
      for (final file in pickedFiles) {
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
          skipped = true;
        } on FileSystemException {
          unreadable = true;
        }
      }
      if (!mounted) return;
      if (skipped) {
        _showMessage(
          AppLocalizations.of(context)!
              .someFilesWereSkippedUseSupportedFilesUpTo10MbEach,
        );
      }
      if (unreadable) {
        _showMessage(
          AppLocalizations.of(context)!
              .couldNotReadTheSelectedFilesPleaseTryAgain,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context)!
              .couldNotReadTheSelectedFilesPleaseTryAgain,
        );
      }
    } finally {
      for (final file in pickedFiles) {
        if (!mounted || !_draftDocuments.contains(file)) {
          unawaited(EntryFileInput.discardPickedFile(file.path));
        }
      }
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
        scrollable: true,
        title: Text(
          isPhoto
              ? AppLocalizations.of(context)!.removeImageLabel
              : file.fileType == 'audio'
              ? AppLocalizations.of(context)!.removeAudioLabel
              : AppLocalizations.of(context)!.removeFileLabel,
        ),
        content: Text(
          AppLocalizations.of(context)!
              .thisAttachmentWillBeRemovedFromTheEntryWhenYouSave,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.remove),
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
        final index = _draftDocuments.indexWhere(
          (draft) => draft.path == file.localPath,
        );
        if (index != -1) {
          _draftDocuments.removeAt(index);
          _documentSizes.remove(file.localPath);
          unawaited(EntryFileInput.discardPickedFile(file.localPath));
        }
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
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failedToPickAnImagePleaseTryAgain,
          ),
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
    _titleFocus.dispose();
    _editorScroll.dispose();
    _content.dispose();
    _textDirty.dispose();
    _recordingFrame.dispose();
    for (final audio in _draftAudios) {
      unawaited(_playback.stopIfPath(audio.path));
    }
    for (final file in _draftDocuments) {
      unawaited(EntryFileInput.discardPickedFile(file.path));
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
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.categoriesAreNotReadyPleaseTryAgain,
          ),
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
      title: AppLocalizations.of(context)!.selectACategory,
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
      if (_title.text.trim().isEmpty) {
        _showMessage(AppLocalizations.of(context)!.enterAnEntryTitle);
        final animation = const Duration(milliseconds: 240);
        if (_titleFieldKey.currentContext == null && _editorScroll.hasClients) {
          await _editorScroll.animateTo(
            0,
            duration: animation,
            curve: Curves.easeOut,
          );
        }
        if (!mounted) return false;
        final titleContext = _titleFieldKey.currentContext;
        if (titleContext != null && titleContext.mounted) {
          await Scrollable.ensureVisible(
            titleContext,
            alignment: 0.12,
            duration: animation,
            curve: Curves.easeOut,
          );
        }
        if (mounted) {
          _formKey.currentState?.validate();
          _titleFocus.requestFocus();
        }
        return false;
      }
      if (!(_formKey.currentState?.validate() ?? false)) return false;
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
        _showMessage(
          AppLocalizations.of(context)!
              .finishUnlockingOrSavingPrivateInformationFirst,
        );
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
          final message = AppLocalizations.of(context)!
              .couldNotSaveTheAttachmentsPleaseTryAgain;
          setState(() => _saveError = message);
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
      final message = AppLocalizations.of(context)!
          .couldNotSaveTheEntryYourTextIsStillInTheForm;
      setState(() => _saveError = message);
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
    for (final file in _draftDocuments) {
      unawaited(EntryFileInput.discardPickedFile(file.path));
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

  Future<void> _saveChecklist(String content) async {
    final entry = _original;
    if (entry == null || !_reading || _isPreparingSave) return;
    final cubit = context.read<EntryCubit>();
    if (cubit.state.isWriting) return;
    final saved = await cubit.saveEntry(
      original: entry,
      title: entry.title ?? '',
      content: content,
      isPinned: entry.isPinned,
      isFavorite: entry.isFavorite,
      checklistOnly: true,
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() => _original = saved);
      _content.markSaved(saved.content);
    } else if (cubit.state.errorMessage case final message?) {
      _showMessage(message);
    }
  }

  Future<void> _toggleReading() async {
    if (context.read<EntryCubit>().state.isWriting) return;
    if (!_reading && _isDirty && !await _save()) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _reading = !_reading);
  }

  Future<void> _togglePrivate() async {
    if (_isPreparingSave || context.read<EntryCubit>().state.isWriting) return;
    if (_privateOpen && _privateController.isAttached) {
      final payload = await _privateController.commit();
      if (!mounted || payload == null) return;
      _privateContent = payload;
    }
    setState(() => _privateOpen = !_privateOpen);
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
        scrollable: true,
        title: Text(AppLocalizations.of(context)!.discardUnsavedChanges),
        content: Text(
          AppLocalizations.of(context)!.ifYouLeaveNowYourChangesWillNotBeSaved,
        ),
        actions: [
          TextButton(
            // The tap handler; null disables the button
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.keepEditing),
          ),
          FilledButton(
            // The tap handler; null disables the button
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.leave),
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
    final location = AppLocalizations.of(context)!.categoryDisplayName(
      _category?.name ?? AppLocalizations.of(context)!.defaultLabel,
    );
    final original = _original;
    final photos = _photos;
    final audios = _audios;
    final documents = _documents;
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
              title: original == null
                  ? Text(AppLocalizations.of(context)!.addEntry)
                  : null,
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
                            tooltip: AppLocalizations.of(context)!.saveChanges,
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
                            ? AppLocalizations.of(context)!.exitReadingMode
                            : AppLocalizations.of(context)!.readingMode,
                        isSelected: _reading,
                        icon: const Icon(Icons.visibility_outlined, size: 22),
                        selectedIcon: const Icon(Icons.edit_outlined, size: 22),
                        onPressed:
                            state.isSaving ||
                                _isPickingAttachment ||
                                _isAudioBusy
                            ? null
                            : _toggleReading,
                      ),
                      IconButton(
                        tooltip: original.isFavorite
                            ? AppLocalizations.of(context)!.removeFromFavorites
                            : AppLocalizations.of(context)!.addToFavorites,
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
                        tooltip: original.isPinned
                            ? AppLocalizations.of(context)!.unpin
                            : AppLocalizations.of(context)!.pin,
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
                          tooltip: AppLocalizations.of(context)!.entryActions,
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
                      controller: _editorScroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (original == null)
                          ReadablePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FieldLabel(
                                  AppLocalizations.of(context)!.category,
                                ),
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
                                    original.title ??
                                        AppLocalizations.of(context)!.untitled,
                                    style: titleStyle,
                                  )
                                else
                                  EntryTitleField(
                                    key: _titleFieldKey,
                                    controller: _title,
                                    focusNode: _titleFocus,
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
                        if (_reading)
                          ReadablePanel(
                            child: _content.text.isEmpty
                                ? Text(AppLocalizations.of(context)!.noTextYet)
                                : EntryDocumentView(
                                    content: _content.text,
                                    onChecklistChanged: _saveChecklist,
                                    checklistEnabled: !state.isWriting,
                                  ),
                          )
                        else
                          EntryDocumentEditor(
                            title: original == null ? _title : null,
                            titleFieldKey: original == null
                                ? _titleFieldKey
                                : null,
                            titleFocus: original == null ? _titleFocus : null,
                            content: _content,
                            enabled: !state.isSaving && !_isPreparingSave,
                            privateOpen: _privateOpen,
                            onTogglePrivate: _togglePrivate,
                          ),
                        if (_privateOpen || _privateContent.isNotEmpty)
                          Padding(
                            key: const ValueKey('entry-private-section'),
                            padding: const EdgeInsets.only(top: 12),
                            child: _privateOpen
                                ? PrivateContentPage(
                                    payload: _privateContent,
                                    isEditable: !_reading,
                                    embedded: true,
                                    controller: _privateController,
                                    onCollapse: _reading
                                        ? _togglePrivate
                                        : null,
                                    onDirtyChanged: (value) {
                                      if (mounted) {
                                        setState(
                                          () => _privateDraftDirty = value,
                                        );
                                      }
                                    },
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() => _privateContent = value);
                                      }
                                    },
                                  )
                                : PrivateContentTile(onTap: _togglePrivate),
                          ),
                        if (!_reading ||
                            photos.isNotEmpty ||
                            audios.isNotEmpty ||
                            documents.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ReadablePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_reading || photos.isNotEmpty) ...[
                                  FieldLabel(
                                    AppLocalizations.of(context)!.images,
                                  ),
                                  if (!_reading) ...[
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed:
                                              state.isSaving ||
                                                  _isPickingAttachment
                                              ? null
                                              : () => _pickImage(
                                                  ImageSource.gallery,
                                                ),
                                          icon: const Icon(
                                            Icons.photo_library_outlined,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(context)!
                                                .gallery,
                                          ),
                                        ),
                                        if (defaultTargetPlatform ==
                                            TargetPlatform.android)
                                          OutlinedButton.icon(
                                            onPressed:
                                                state.isSaving ||
                                                    _isPickingAttachment
                                                ? null
                                                : () => _pickImage(
                                                    ImageSource.camera,
                                                  ),
                                            icon: const Icon(
                                              Icons.camera_alt_outlined,
                                            ),
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .camera,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  EntryPhotoGallery(
                                    photos: photos,
                                    isEnabled:
                                        !state.isSaving &&
                                        !_isPreparingSave &&
                                        !_isPickingAttachment &&
                                        !_isAudioBusy,
                                    onCaption: _reading
                                        ? null
                                        : (index) =>
                                              _renameAttachment(photos[index]),
                                    onRemove: _reading
                                        ? null
                                        : (index) =>
                                              _removeMedia(photos[index]),
                                  ),
                                ],
                                if (!_reading || audios.isNotEmpty) ...[
                                  if (!_reading || photos.isNotEmpty)
                                    const SizedBox(height: 20),
                                  FieldLabel(
                                    AppLocalizations.of(context)!.audio,
                                  ),
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
                                    if (!_reading) ...[
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
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .record,
                                            ),
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
                                            label: Text(
                                              AppLocalizations.of(context)!
                                                  .addAudio,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    EntryAudioPlayer(
                                      attachments: audios,
                                      isEnabled:
                                          !state.isSaving &&
                                          !_isPreparingSave &&
                                          !_isAudioBusy,
                                      onRename: _reading
                                          ? null
                                          : _renameAttachment,
                                      onRemove: _reading ? null : _removeMedia,
                                    ),
                                  ],
                                ],
                                if (!_reading || documents.isNotEmpty) ...[
                                  if (!_reading ||
                                      photos.isNotEmpty ||
                                      audios.isNotEmpty)
                                    const SizedBox(height: 20),
                                  FieldLabel(
                                    AppLocalizations.of(context)!.files,
                                  ),
                                  if (!_reading) ...[
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
                                        icon: const Icon(
                                          Icons.attach_file,
                                          size: 20,
                                        ),
                                        label: Text(
                                          AppLocalizations.of(context)!
                                              .addFiles,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .documentsZipAndVideoUpTo10MbEach,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  EntryFileList(
                                    files: documents,
                                    onRemove: _reading ? null : _removeMedia,
                                    isEnabled:
                                        !state.isSaving &&
                                        !_isPreparingSave &&
                                        !_isAudioBusy &&
                                        !_isPickingAttachment,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
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
                                    _isFavorite
                                        ? AppLocalizations.of(context)!
                                              .favorited
                                        : AppLocalizations.of(context)!
                                              .favorite,
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
                                  label: Text(
                                    _isPinned
                                        ? AppLocalizations.of(context)!.pinned
                                        : AppLocalizations.of(context)!.pin,
                                  ),
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
                            child: Text(
                              state.isSaving
                                  ? AppLocalizations.of(context)!.saving
                                  : AppLocalizations.of(context)!.save,
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              AppLocalizations.of(context)!.entryDates(
                                formatEntryDate(original.createdAt),
                                formatEntryDate(original.updatedAt),
                              ),
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
