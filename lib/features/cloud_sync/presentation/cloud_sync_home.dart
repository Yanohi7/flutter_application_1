import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../category/presentation/cubit/category_cubit.dart';
import '../../category/presentation/cubit/category_state.dart';
import '../../entry/presentation/cubit/entry_cubit.dart';
import '../../entry/presentation/cubit/entry_state.dart';
import '../../profile/data/profile_store.dart';
import 'cloud_sync_controller.dart';

/// Only applies automatic downloads while the workspace is the active route.
class CloudSyncHome extends StatefulWidget {
  const CloudSyncHome({super.key, required this.child});
  final Widget child;

  @override
  State<CloudSyncHome> createState() => _CloudSyncHomeState();
}

class _CloudSyncHomeState extends State<CloudSyncHome> {
  CloudSyncController? _sync;
  int _downloads = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = context.read<CloudSyncController?>();
    if (!identical(sync, _sync)) {
      _sync?.removeListener(_onSyncChanged);
      _sync = sync;
      _downloads = sync?.downloadedCount ?? 0;
      sync?.addListener(_onSyncChanged);
    }
    _sync?.setWorkspaceVisible(ModalRoute.isCurrentOf(context) ?? true);
  }

  void _onSyncChanged() {
    final sync = _sync;
    if (sync == null || sync.downloadedCount == _downloads) return;
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
    _sync?.setWorkspaceVisible(false);
    super.dispose();
  }
}
