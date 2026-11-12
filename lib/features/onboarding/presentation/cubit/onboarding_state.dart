// Describe startup progress and onboarding completion for the interface

enum OnboardingStatus { checking, introduction, completed, failure }

class OnboardingState {
  final OnboardingStatus status;
  final bool isSaving;
  final String? errorMessage;

  const OnboardingState({
    this.status = OnboardingStatus.checking,
    this.isSaving = false,
    this.errorMessage,
  });
}
