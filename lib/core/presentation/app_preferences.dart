import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_palette.dart';

final appPreferences = AppPreferences();

enum NoteCardSize {
  compact('Compact', Icons.view_comfy_alt_outlined),
  standard('Standard', Icons.grid_view_outlined),
  large('Large', Icons.view_agenda_outlined);

  const NoteCardSize(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Persists the two appearance choices as one atomic preferences document.
class AppPreferences extends ChangeNotifier {
  AppPreferences({SharedPreferencesAsync? storage})
    : _providedStorage = storage;

  final SharedPreferencesAsync? _providedStorage;
  SharedPreferencesAsync get _storage =>
      _providedStorage ?? SharedPreferencesAsync();
  static const storageKey = 'app_preferences_v1';
  String _activeStorageKey = storageKey;
  bool _premiumPreviewEnabled = false;
  bool _allowPremiumPreview = true;
  Map<String, DateTime> _themeTrials = {};
  Set<String> _themeAdProgress = {};
  Timer? _trialTimer;
  String? _backgroundPath;
  DateTime? _photoTrialEnds;
  bool _photoTrialProgress = false;
  bool _isTrialPhoto = false;
  double _backgroundFade = 0.88;
  double _surfaceOpacity = 1;
  double _photoX = 0, _photoY = 0, _photoZoom = 1;
  String? get storedBackgroundPath => _backgroundPath;
  String? get backgroundPath =>
      _isTrialPhoto && !canChangeBackground ? null : _backgroundPath;
  bool get canChangeBackground =>
      isPremium || (_photoTrialEnds?.isAfter(DateTime.now()) ?? false);
  int get completedPhotoAds => _photoTrialProgress ? 1 : 0;
  double get backgroundFade => _backgroundFade;
  double get surfaceOpacity => _surfaceOpacity;
  double get photoX => _photoX;
  double get photoY => _photoY;
  double get photoZoom => _photoZoom;
  String get backgroundStyle => palette.backgroundStyle;
  bool get premiumPreviewEnabled => _premiumPreviewEnabled;
  bool _isSaving = false;
  bool _isExpandedPhotos = false;
  ThemeMode _mode = ThemeMode.system;
  AppPalette _palette = AppPalette.presets.first;
  NoteCardSize _noteCardSize = NoteCardSize.standard;

  // Local preview preserves the existing prototype experience, without claiming a purchase.
  bool get allowPremiumPreview => _allowPremiumPreview;
  bool get isPremium => _allowPremiumPreview && _premiumPreviewEnabled;
  bool get isSaving => _isSaving;
  bool get isExpandedPhotos => _isExpandedPhotos;
  ThemeMode get mode => _mode;
  AppPalette get palette =>
      canUsePalette(_palette) ? _palette : AppPalette.graphite;
  NoteCardSize get noteCardSize => _noteCardSize;

  Future<void> load({
    String key = storageKey,
    bool allowPremiumPreview = true,
  }) async {
    _activeStorageKey = key;
    _allowPremiumPreview = allowPremiumPreview;
    _themeTrials = {};
    _themeAdProgress = {};
    _mode = ThemeMode.system;
    _palette = AppPalette.presets.first;
    _noteCardSize = NoteCardSize.standard;
    _isExpandedPhotos = false;
    _premiumPreviewEnabled = false;
    _backgroundPath = null;
    _photoTrialEnds = null;
    _photoTrialProgress = false;
    _isTrialPhoto = false;
    _backgroundFade = 0.88;
    _surfaceOpacity = 1;
    _photoX = 0;
    _photoY = 0;
    _photoZoom = 1;
    try {
      final stored = await _storage.getString(_activeStorageKey);
      if (stored != null) {
        final values = jsonDecode(stored) as Map<String, dynamic>;
        _noteCardSize = NoteCardSize.values.firstWhere(
          (size) => size.name == values['noteCardSize'],
          orElse: () => NoteCardSize.standard,
        );
        _premiumPreviewEnabled =
            values['premiumPreviewEnabled'] == true ||
            values['isPremium'] == true;
        final trials = values['themeTrials'];
        if (trials is Map) {
          for (final palette in AppPalette.presets.where(
            (item) => item.isPremium,
          )) {
            final value = trials[palette.id];
            final expires = value is String ? DateTime.tryParse(value) : null;
            if (expires != null && expires.isAfter(DateTime.now())) {
              _themeTrials[palette.id] = expires;
            }
          }
        }
        final progress = values['themeAdProgress'];
        if (progress is List) {
          _themeAdProgress = {
            for (final palette in AppPalette.presets.where(
              (item) => item.isPremium,
            ))
              if (progress.contains(palette.id)) palette.id,
          };
        }
        _backgroundPath = values['backgroundPath'] as String?;
        final photoTrialEnds = values['photoTrialEnds'];
        _photoTrialEnds = photoTrialEnds is String
            ? DateTime.tryParse(photoTrialEnds)
            : null;
        _photoTrialProgress = values['photoTrialProgress'] == true;
        _isTrialPhoto = values['isTrialPhoto'] == true;
        _backgroundFade =
            ((values['backgroundFade'] as num?)?.toDouble() ?? 0.88).clamp(
              0.0,
              0.96,
            );
        _surfaceOpacity = ((values['surfaceOpacity'] as num?)?.toDouble() ?? 1)
            .clamp(0.25, 1);
        _photoX = ((values['photoX'] as num?)?.toDouble() ?? 0).clamp(
          -1.0,
          1.0,
        );
        _photoY = ((values['photoY'] as num?)?.toDouble() ?? 0).clamp(
          -1.0,
          1.0,
        );
        _photoZoom = ((values['photoZoom'] as num?)?.toDouble() ?? 1).clamp(
          1.0,
          3.0,
        );
        _isExpandedPhotos = values['isExpandedPhotos'] == true;
        _mode = ThemeMode.values.firstWhere(
          (mode) => mode.name == values['mode'],
          orElse: () => ThemeMode.system,
        );
        // Migrate old independent accents and backgrounds to a single palette.
        final id =
            values['palette'] ??
            (values['backgroundStyle'] != 'plain'
                ? values['backgroundStyle']
                : null) ??
            switch (values['accent']) {
              0xFF6289CC => 'blue',
              0xFF66A58C => 'green',
              0xFFB38BC5 => 'purple',
              _ => 'graphite',
            };
        _palette = AppPalette.presets.firstWhere(
          (palette) => palette.id == id && canUsePalette(palette),
          orElse: () => AppPalette.presets.first,
        );
      }
    } catch (error) {
      debugPrint('Could not load appearance preferences: $error');
    }
    _scheduleTrialExpiry();
    notifyListeners();
  }

  Future<void> _save({
    ThemeMode? mode,
    AppPalette? palette,
    bool? isExpandedPhotos,
    bool? premiumPreviewEnabled,
    String? backgroundPath,
    bool replaceBackground = false,
    double? backgroundFade,
    double? surfaceOpacity,
    double? photoX,
    double? photoY,
    double? photoZoom,
    NoteCardSize? noteCardSize,
    Map<String, DateTime>? themeTrials,
    Set<String>? themeAdProgress,
    DateTime? photoTrialEnds,
    bool? photoTrialProgress,
    bool? isTrialPhoto,
  }) async {
    if (_isSaving) throw StateError('Preferences are still being saved');
    final nextPreview = premiumPreviewEnabled ?? _premiumPreviewEnabled;
    final nextPath = replaceBackground ? backgroundPath : _backgroundPath;
    final nextFade = backgroundFade ?? _backgroundFade;
    final nextOpacity = surfaceOpacity ?? _surfaceOpacity;
    final nextX = photoX ?? _photoX;
    final nextY = photoY ?? _photoY;
    final nextZoom = photoZoom ?? _photoZoom;
    final nextMode = mode ?? _mode;
    final nextPalette = palette ?? _palette;
    final nextExpandedPhotos = isExpandedPhotos ?? _isExpandedPhotos;
    final nextNoteCardSize = noteCardSize ?? _noteCardSize;
    final nextTrials = themeTrials ?? _themeTrials;
    final nextProgress = themeAdProgress ?? _themeAdProgress;
    final nextPhotoTrialEnds = photoTrialEnds ?? _photoTrialEnds;
    final nextPhotoProgress = photoTrialProgress ?? _photoTrialProgress;
    final nextIsTrialPhoto = isTrialPhoto ?? _isTrialPhoto;
    _isSaving = true;
    notifyListeners();
    try {
      await _storage.setString(
        _activeStorageKey,
        jsonEncode({
          'premiumPreviewEnabled': nextPreview,
          'backgroundPath': nextPath,
          'backgroundFade': nextFade,
          'surfaceOpacity': nextOpacity,
          'photoX': nextX,
          'photoY': nextY,
          'photoZoom': nextZoom,
          'mode': nextMode.name,
          'palette': nextPalette.id,
          'isExpandedPhotos': nextExpandedPhotos,
          'noteCardSize': nextNoteCardSize.name,
          'themeTrials': {
            for (final entry in nextTrials.entries)
              entry.key: entry.value.toIso8601String(),
          },
          'themeAdProgress': nextProgress.toList(),
          'photoTrialEnds': nextPhotoTrialEnds?.toIso8601String(),
          'photoTrialProgress': nextPhotoProgress,
          'isTrialPhoto': nextIsTrialPhoto,
        }),
      );
      _premiumPreviewEnabled = nextPreview;
      _backgroundPath = nextPath;
      _backgroundFade = nextFade;
      _surfaceOpacity = nextOpacity;
      _photoX = nextX;
      _photoY = nextY;
      _photoZoom = nextZoom;
      _mode = nextMode;
      _palette = nextPalette;
      _isExpandedPhotos = nextExpandedPhotos;
      _noteCardSize = nextNoteCardSize;
      _themeTrials = nextTrials;
      _themeAdProgress = nextProgress;
      _photoTrialEnds = nextPhotoTrialEnds;
      _photoTrialProgress = nextPhotoProgress;
      _isTrialPhoto = nextIsTrialPhoto;
      _scheduleTrialExpiry();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> setPremiumPreview(bool enabled) {
    if (enabled && !_allowPremiumPreview) {
      throw StateError('Premium preview is unavailable.');
    }
    return _save(
      premiumPreviewEnabled: enabled,
      palette: !enabled && _palette.isPremium ? AppPalette.graphite : _palette,
    );
  }

  Future<void> applyPhoto(
    String path,
    double x,
    double y,
    double zoom,
    double fade,
    double opacity,
  ) {
    if (!canChangeBackground && path != backgroundPath) {
      throw const FormatException('Your photo background access has ended.');
    }
    return _save(
      backgroundPath: path,
      replaceBackground: true,
      isTrialPhoto: path == _backgroundPath ? _isTrialPhoto : !isPremium,
      photoX: x.clamp(-1.0, 1.0),
      photoY: y.clamp(-1.0, 1.0),
      photoZoom: zoom.clamp(1.0, 3.0),
      backgroundFade: fade.clamp(0.0, 0.96),
      surfaceOpacity: opacity.clamp(0.25, 1.0),
    );
  }

  Future<void> setBackground(String? path) =>
      _save(backgroundPath: path, replaceBackground: true, isTrialPhoto: false);
  Future<void> setSurfaceOpacity(double value) =>
      _save(surfaceOpacity: value.clamp(0.25, 1.0));
  Future<void> setBackgroundFade(double value) =>
      _save(backgroundFade: value.clamp(0.0, 0.96));
  Future<void> setExpandedPhotos(bool value) => _save(isExpandedPhotos: value);
  Future<void> setMode(ThemeMode mode) => _save(mode: mode);
  Future<void> setNoteCardSize(NoteCardSize size) => _save(noteCardSize: size);
  Future<void> setPalette(AppPalette palette) {
    if (!AppPalette.presets.contains(palette)) {
      throw ArgumentError('Unknown color theme');
    }
    if (!canUsePalette(palette)) {
      throw StateError('Premium is required for this theme');
    }
    return _save(palette: palette);
  }

  bool canUsePalette(AppPalette palette) =>
      !palette.isPremium ||
      isPremium ||
      (_themeTrials[palette.id]?.isAfter(DateTime.now()) ?? false);

  int completedThemeAds(AppPalette palette) =>
      _themeAdProgress.contains(palette.id) ? 1 : 0;

  /// Called only after the ad SDK confirms a reward.
  Future<bool> recordThemeAd(AppPalette palette) async {
    if (!palette.isPremium || !AppPalette.presets.contains(palette)) {
      throw ArgumentError('Unknown Premium color theme.');
    }
    final progress = {..._themeAdProgress};
    if (progress.add(palette.id)) {
      await _save(themeAdProgress: progress);
      return false;
    }
    progress.remove(palette.id);
    await _save(
      palette: palette,
      themeAdProgress: progress,
      themeTrials: {
        ..._themeTrials,
        palette.id: DateTime.now().toUtc().add(const Duration(hours: 24)),
      },
    );
    return true;
  }

  /// Grants photo background access after two confirmed rewards.
  Future<bool> recordPhotoAd() async {
    if (canChangeBackground) return true;
    if (!_photoTrialProgress) {
      await _save(photoTrialProgress: true);
      return false;
    }
    await _save(
      photoTrialProgress: false,
      photoTrialEnds: DateTime.now().toUtc().add(const Duration(hours: 24)),
    );
    return true;
  }

  void _scheduleTrialExpiry() {
    _trialTimer?.cancel();
    final now = DateTime.now();
    final expirations = [
      ..._themeTrials.values,
      ?_photoTrialEnds,
    ].where((value) => value.isAfter(now)).toList()..sort();
    if (expirations.isEmpty) return;
    _trialTimer = Timer(expirations.first.difference(now), () {
      notifyListeners();
      _scheduleTrialExpiry();
    });
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    super.dispose();
  }
}
