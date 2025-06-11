import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/vibration_service.dart';

// Events
abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object> get props => [];
}

class StartNavigation extends NavigationEvent {
  final String destination;

  const StartNavigation(this.destination);

  @override
  List<Object> get props => [destination];
}

class StopNavigation extends NavigationEvent {}

class UpdateLocation extends NavigationEvent {
  final double latitude;
  final double longitude;

  const UpdateLocation({required this.latitude, required this.longitude});

  @override
  List<Object> get props => [latitude, longitude];
}

class ApproachingTurn extends NavigationEvent {
  final String turnDirection; // "left", "right", "uturn"

  const ApproachingTurn(this.turnDirection);

  @override
  List<Object> get props => [turnDirection];
}

class OffRoute extends NavigationEvent {}

class OnRoute extends NavigationEvent {}

class ReachedDestination extends NavigationEvent {}

class ApproachingCrossing extends NavigationEvent {}

class ApproachingHazard extends NavigationEvent {
  final String hazardType;

  const ApproachingHazard(this.hazardType);

  @override
  List<Object> get props => [hazardType];
}

// States
abstract class NavigationState extends Equatable {
  const NavigationState();

  @override
  List<Object> get props => [];
}

class NavigationInitial extends NavigationState {}

class NavigationActive extends NavigationState {
  final String destination;
  final double currentLatitude;
  final double currentLongitude;
  final bool isOnRoute;
  final String? nextManeuver;

  const NavigationActive({
    required this.destination,
    required this.currentLatitude,
    required this.currentLongitude,
    this.isOnRoute = true,
    this.nextManeuver,
  });

  NavigationActive copyWith({
    String? destination,
    double? currentLatitude,
    double? currentLongitude,
    bool? isOnRoute,
    String? nextManeuver,
  }) {
    return NavigationActive(
      destination: destination ?? this.destination,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      isOnRoute: isOnRoute ?? this.isOnRoute,
      nextManeuver: nextManeuver ?? this.nextManeuver,
    );
  }

  @override
  List<Object> get props => [
    destination,
    currentLatitude,
    currentLongitude,
    isOnRoute,
    if (nextManeuver != null) nextManeuver!,
  ];
}

class NavigationCompleted extends NavigationState {}

class NavigationError extends NavigationState {
  final String message;

  const NavigationError(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
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
