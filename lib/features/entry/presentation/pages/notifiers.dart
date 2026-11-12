// Keep the legacy test notifier while the app uses persisted AppPreferences

import 'package:flutter/material.dart';

// Retained for existing widget tests that have not migrated to saved preferences
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);
