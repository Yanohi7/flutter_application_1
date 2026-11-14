import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../category/presentation/cubit/category_cubit.dart';
import '../../category/presentation/cubit/category_state.dart';
import '../../entry/presentation/cubit/entry_cubit.dart';
import '../../entry/presentation/cubit/entry_state.dart';
import '../../profile/data/profile_store.dart';
import 'cloud_sync_controller.dart';
import 'guest_transfer_dialog.dart';

/// Only applies automatic downloads while the workspace is the active route.
class CloudSyncHome extends StatefulWidget {
  const CloudSyncHome({super.key, required this.child});
  final Widget child;

  @override
  State<CloudSyncHome> createState() => _CloudSyncHomeState();
}

class _CloudSyncHomeState extends State<CloudSyncHome> {
  CloudSyncController? _sync;
  int? _userId;
  int _downloads = 0;
  bool _guestTransferOffered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = context.read<CloudSyncController?>();
    if (!identical(sync, _sync)) {
      _sync?.removeListener(_onSyncChanged);
      _sync = sync;
      _userId = sync?.activeUserId;
      _downloads = sync?.downloadedCount ?? 0;
      sync?.addListener(_onSyncChanged);
    }
    _sync?.setWorkspaceVisible(ModalRoute.isCurrentOf(context) ?? true);
    if (sync != null) _scheduleGuestTransferOffer(sync);
  }

  void _onSyncChanged() {
    final sync = _sync;
    if (sync == null || sync.activeUserId != _userId) return;
    _scheduleGuestTransferOffer(sync);
    if (sync.downloadedCount == _downloads) return;
    _downloads = sync.downloadedCount;
    unawaited(context.read<CategoryCubit>().loadCategories());
    unawaited(context.read<EntryCubit>().loadEntries());
    final profile = context.read<ProfileStore?>();
    if (profile != null) {
      unawaited(
        profile.load().catchError((Object error) {
          debugPrint(
            'Could not refresh the synced profile: ${error.runtimeType}',
          );
        }),
      );
    }
  }

  void _scheduleGuestTransferOffer(CloudSyncController sync) {
    if (!sync.guestTransferAvailable ||
        sync.initialSyncPending ||
        sync.busy ||
        _guestTransferOffered ||
        ModalRoute.isCurrentOf(context) == false) {
      return;
    }
    _guestTransferOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || sync.activeUserId != _userId) return;
      if (sync.busy ||
          sync.initialSyncPending ||
          !sync.guestTransferAvailable ||
          ModalRoute.isCurrentOf(context) == false) {
        _guestTransferOffered = false;
        return;
      }
      unawaited(offerGuestTransfer(context, sync));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = _sync;
    if (sync == null) return widget.child;
    return MultiBlocListener(
      listeners: [
        BlocListener<EntryCubit, EntryState>(
          listenWhen: (before, after) =>
              !identical(before.entries, after.entries),
          listener: (_, _) => sync.workspaceChanged(),
        ),
        BlocListener<CategoryCubit, CategoryState>(
          listenWhen: (before, after) =>
              !identical(before.categories, after.categories),
          listener: (_, _) => sync.workspaceChanged(),
        ),
      ],
      child: ListenableBuilder(
        listenable: sync,
        child: widget.child,
        builder: (_, child) =>
            AbsorbPointer(absorbing: sync.applyingRemote, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSyncChanged);
    if (_sync?.activeUserId == _userId) {
      _sync?.setWorkspaceVisible(false);
    }
    super.dispose();
  }
}
