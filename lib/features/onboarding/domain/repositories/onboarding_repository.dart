// Define how onboarding completion can be read and saved

abstract class OnboardingRepository {
  /// Return true if the user has completed onboarding, false if not
  Future<bool> isOnboardingComplete();

  /// Save that the user has completed onboarding
  Future<void> setOnboardingComplete();
}
