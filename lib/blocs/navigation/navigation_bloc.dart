import 'package:bloc/bloc.dart';
import '../../services/vibration_service.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final VibrationService _vibrationService = VibrationService();

  NavigationBloc() : super(NavigationInitial()) {
    on<StartNavigation>(_onStartNavigation);
    on<StopNavigation>(_onStopNavigation);
    on<UpdateLocation>(_onUpdateLocation);
    on<ApproachingTurn>(_onApproachingTurn);
    on<OffRoute>(_onOffRoute);
    on<OnRoute>(_onOnRoute);
    on<ReachedDestination>(_onReachedDestination);
    on<ApproachingCrossing>(_onApproachingCrossing);
    on<ApproachingHazard>(_onApproachingHazard);
  }

  void _onStartNavigation(
    StartNavigation event,
    Emitter<NavigationState> emit,
  ) {
    // Will implement actual navigation logic
    emit(
      NavigationActive(
        destination: event.destination,
        currentLatitude: 0.0,
        currentLongitude: 0.0,
      ),
    );
  }

  void _onStopNavigation(StopNavigation event, Emitter<NavigationState> emit) {
    _vibrationService.stopVibration();
    emit(NavigationInitial());
  }

  void _onUpdateLocation(UpdateLocation event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;
      emit(
        currentState.copyWith(
          currentLatitude: event.latitude,
          currentLongitude: event.longitude,
        ),
      );
    }
  }

  void _onApproachingTurn(
    ApproachingTurn event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Provide appropriate vibration feedback based on turn direction
      switch (event.turnDirection) {
        case 'left':
          _vibrationService.leftTurnFeedback();
          break;
        case 'right':
          _vibrationService.rightTurnFeedback();
          break;
        case 'uturn':
          _vibrationService.uTurnFeedback();
          break;
        default:
          _vibrationService.approachingTurnFeedback();
      }

      emit(currentState.copyWith(nextManeuver: event.turnDirection));
    }
  }

  void _onOffRoute(OffRoute event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;
      _vibrationService.wrongDirectionFeedback();
      emit(currentState.copyWith(isOnRoute: false));
    }
  }

  void _onOnRoute(OnRoute event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;
      if (!currentState.isOnRoute) {
        _vibrationService.onRouteFeedback();
        emit(currentState.copyWith(isOnRoute: true));
      }
    }
  }

  void _onReachedDestination(
    ReachedDestination event,
    Emitter<NavigationState> emit,
  ) {
    _vibrationService.destinationReachedFeedback();
    emit(NavigationCompleted());
  }

  void _onApproachingCrossing(
    ApproachingCrossing event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationActive) {
      _vibrationService.crossingStreetFeedback();
    }
  }

  void _onApproachingHazard(
    ApproachingHazard event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationActive) {
      _vibrationService.hazardWarningFeedback();
    }
  }
}
