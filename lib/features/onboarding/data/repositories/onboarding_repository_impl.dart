import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl({this.repeat = false});

  final bool repeat;
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static const _completedKey = 'onboarding_complete';

  @override
  Future<bool> isOnboardingComplete() async {
    if (repeat) return false;
    final completed = await _preferences.getBool(_completedKey);
    return completed ?? false;
  }

  @override
  Future<void> setOnboardingComplete() async {
    if (repeat) return;
    await _preferences.setBool(_completedKey, true);
  }
}
