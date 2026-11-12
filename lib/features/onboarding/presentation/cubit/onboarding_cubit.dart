// Read onboarding progress and publish the appropriate startup screen state

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepository _repository;

  OnboardingCubit(this._repository) : super(const OnboardingState());

  Future<void> load() async {
    if (isClosed) return;

    emit(const OnboardingState());

    try {
      final completed = await _repository.isOnboardingComplete();

      if (isClosed) return;

      emit(
        OnboardingState(
          status: completed
              ? OnboardingStatus.completed
              : OnboardingStatus.introduction,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        OnboardingState(
          status: OnboardingStatus.failure,
          errorMessage: 'Could not load startup preferences. Please try again.',
        ),
      );
    }
  }

  Future<void> complete() async {
    if (isClosed ||
        state.isSaving ||
        state.status != OnboardingStatus.introduction) {
      return;
    }

    // Open the app immediately so preference storage cannot trap the user in the tutorial
    emit(const OnboardingState(status: OnboardingStatus.completed));

    try {
      await _repository.setOnboardingComplete().timeout(
        const Duration(seconds: 5),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        OnboardingState(
          status: OnboardingStatus.completed,
          errorMessage: 'Tutorial closed, but progress could not be saved. It may appear again next time.',
        ),
      );
    }
  }
}
