import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_information.dart';
import '../../services/location_service.dart';
import '../../services/mapping_service.dart';
import '../../services/navigation_monitoring_service.dart';
import '../../services/vibration_service.dart';
import '../../services/routing_service.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final VibrationService _vibrationService = VibrationService();
  final MappingService _mappingService = MappingService();
  final LocationService _locationService = LocationService();
  final NavigationMonitoringService _navigationService =
      NavigationMonitoringService();
  final RoutingService _routingService = RoutingService();

  // Subscriptions
  StreamSubscription<NavigationStatus>? _statusSubscription;
  StreamSubscription<LatLng>? _positionSubscription;
  StreamSubscription<double>? _deviationSubscription;
  StreamSubscription<RouteStep>? _upcomingTurnSubscription;
  StreamSubscription<LatLng>? _destinationReachedSubscription;
  StreamSubscription<bool>? _reroutingSubscription;
  StreamSubscription<String>? _errorSubscription;

  NavigationBloc() : super(NavigationIdle()) {
    on<StartNavigation>(_onStartNavigation);
    on<StartNavigatingRoute>(_onStartNavigatingRoute);
    on<StopNavigation>(_onStopNavigation);
    on<PauseNavigation>(_onPauseNavigation);
    on<ResumeNavigation>(_onResumeNavigation);
    on<UpdateLocation>(_onUpdateLocation);
    on<ApproachingTurn>(_onApproachingTurn);
    on<TurnCompleted>(_onTurnCompleted);
    on<StartRerouting>(_onStartRerouting);
    on<ReroutingComplete>(_onReroutingComplete);
    on<ReroutingFailed>(_onReroutingFailed);
    on<OffRoute>(_onOffRoute);
    on<OnRoute>(_onOnRoute);
    on<DestinationReached>(_onDestinationReached);
    on<ApproachingCrossing>(_onApproachingCrossing);
    on<ApproachingHazard>(_onApproachingHazard);
    on<RouteDeviation>(_onRouteDeviation);
    on<_NavigationErrorReceived>(_onNavigationErrorReceived);

    // Subscribe to navigation service events
    _subscribeToNavigationService();
  }

  void _subscribeToNavigationService() {
    // Subscribe to navigation status changes
    _statusSubscription = _navigationService.statusStream.listen((status) {
      _handleNavigationStatusChange(status);
    });

    // Subscribe to position updates
    _positionSubscription = _navigationService.positionStream.listen((
      position,
    ) {
      add(UpdateLocation(position));
    });

    // Subscribe to route deviation events
    _deviationSubscription = _navigationService.deviationStream.listen((
      deviation,
    ) {
      if (_navigationService.currentPosition != null) {
        add(
          RouteDeviation(
            position: _navigationService.currentPosition!,
            deviationDistance: deviation,
          ),
        );
      }
    });

    // Subscribe to upcoming turn events
    _upcomingTurnSubscription = _navigationService.upcomingTurnStream.listen((
      step,
    ) {
      add(ApproachingTurn(turnDirection: step.turnDirection, step: step));
    });

    // Subscribe to destination reached events
    _destinationReachedSubscription = _navigationService
        .destinationReachedStream
        .listen((position) {
          add(DestinationReached(position));
        });

    // Subscribe to rerouting events
    _reroutingSubscription = _navigationService.reroutingStream.listen((
      isRerouting,
    ) {
      if (isRerouting && _navigationService.currentPosition != null) {
        add(
          StartRerouting(
            currentPosition: _navigationService.currentPosition!,
            deviationDistance: 0.0, // We don't have this value from the stream
          ),
        );
      }
    });
    // Subscribe to error events
    _errorSubscription = _navigationService.errorStream.listen((errorMessage) {
      add(_NavigationErrorReceived(errorMessage));
    });
  }

  void _handleNavigationStatusChange(NavigationStatus status) {
    switch (status) {
      case NavigationStatus.idle:
        if (state is! NavigationIdle) {
          add(StopNavigation());
        }
        break;
      case NavigationStatus.active:
        // Active state is handled by position updates
        break;
      case NavigationStatus.rerouting:
        if (state is NavigationActive &&
            _navigationService.currentPosition != null) {
          add(
            StartRerouting(
              currentPosition: _navigationService.currentPosition!,
              deviationDistance: 0.0, // Default value
            ),
          );
        }
        break;
      case NavigationStatus.arrived:
        if (state is NavigationActive &&
            _navigationService.currentPosition != null) {
          add(DestinationReached(_navigationService.currentPosition!));
        }
        break;
      case NavigationStatus.error:
        // Error state is handled by error subscription
        break;
    }
  }

  Future<void> _onStartNavigation(
    StartNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      // Get current position
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        emit(NavigationError(message: "Couldn't get current location"));
        return;
      }

      // TODO: Implement geocoding to get destination coordinates
      // For now, just use a placeholder destination 1km north
      final originLatLng = LatLng(position.latitude, position.longitude);
      final destinationLatLng = LatLng(
        position.latitude + 0.01, // Roughly 1km north
        position.longitude,
      );

      // Calculate route
      final route = await _routingService.calculateRoute(
        originLatLng,
        destinationLatLng,
        mode: TravelMode.walking,
      );

      if (route == null) {
        emit(NavigationError(message: "Couldn't calculate route"));
        return;
      }

      // Start navigation with the calculated route
      add(StartNavigatingRoute(route));
    } catch (e) {
      emit(NavigationError(message: "Error starting navigation: $e"));
    }
  }

  Future<void> _onStartNavigatingRoute(
    StartNavigatingRoute event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      // Start navigation monitoring
      final success = await _navigationService.startNavigation(event.route);

      if (!success) {
        emit(NavigationError(message: "Failed to start navigation monitoring"));
        return;
      }

      // Get current position
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        _navigationService.stopNavigation();
        emit(NavigationError(message: "Couldn't get current location"));
        return;
      }

      // Update the map with the route
      _mappingService.clearMarkers();
      _mappingService.clearPolylines();

      _mappingService.addMarker(
        id: 'origin',
        position: event.route.origin.position,
        title: 'Start',
      );

      _mappingService.addMarker(
        id: 'destination',
        position: event.route.destination.position,
        title: event.route.destination.name,
      );

      _mappingService.addPolyline(
        id: 'route',
        points: event.route.polylinePoints,
      );

      // Initialize active navigation state
      final currentPosition = LatLng(position.latitude, position.longitude);
      emit(
        NavigationActive(
          destination: event.route.destination.name,
          currentPosition: currentPosition,
          route: event.route,
          distanceToDestination: event.route.distanceMeters,
          estimatedTimeInSeconds: event.route.durationSeconds,
        ),
      );

      // Provide initial feedback
      _vibrationService.onRouteFeedback();
    } catch (e) {
      emit(NavigationError(message: "Error starting navigation: $e"));
    }
  }

  Future<void> _onStopNavigation(
    StopNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    await _navigationService.stopNavigation();
    _mappingService.clearMarkers();
    _mappingService.clearPolylines();
    _vibrationService.stopVibration();
    emit(NavigationIdle());
  }

  void _onPauseNavigation(
    PauseNavigation event,
    Emitter<NavigationState> emit,
  ) {
    // Implementation for pausing navigation
    // This would typically pause location updates and feedback
    // but retain the current route and state
  }

  void _onResumeNavigation(
    ResumeNavigation event,
    Emitter<NavigationState> emit,
  ) {
    // Implementation for resuming navigation
    // This would restart location updates and feedback
  }

  void _onUpdateLocation(UpdateLocation event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Update remaining distance if route is available
      int? remainingDistance;
      if (_navigationService.distanceToDestination != null) {
        remainingDistance = _navigationService.distanceToDestination;
      } else {
        remainingDistance = currentState.route.getRemainingDistance(
          event.position,
        );
      }

      // Update state with new position and info
      emit(
        currentState.copyWith(
          currentPosition: event.position,
          distanceToDestination: remainingDistance,
          estimatedTimeInSeconds: _navigationService.estimatedTimeRemaining,
          isOnRoute: _navigationService.isOnRoute,
          nextStep: _navigationService.nextStep,
          lastUpdated: DateTime.now(),
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

      // Update state with next step information
      emit(
        currentState.copyWith(
          nextStep: event.step,
          lastUpdated: DateTime.now(),
        ),
      );
    }
  }

  void _onTurnCompleted(TurnCompleted event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // If this was our next step, clear it
      if (currentState.nextStep == event.completedStep) {
        emit(
          currentState.copyWith(nextStep: null, lastUpdated: DateTime.now()),
        );
      }
    }
  }

  void _onStartRerouting(StartRerouting event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      emit(
        NavigationRerouting(
          currentPosition: event.currentPosition,
          destination: currentState.destination,
          deviationDistance: event.deviationDistance,
        ),
      );

      // In a real implementation, we would start recalculating the route here
      // For now, we'll just rely on the navigation service
    }
  }

  void _onReroutingComplete(
    ReroutingComplete event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationRerouting &&
        _navigationService.currentPosition != null) {
      // Update the map with the new route
      _mappingService.clearPolylines();
      _mappingService.addPolyline(
        id: 'route',
        points: event.newRoute.polylinePoints,
      );

      // Resume active navigation with the new route
      emit(
        NavigationActive(
          destination: event.newRoute.destination.name,
          currentPosition: _navigationService.currentPosition!,
          route: event.newRoute,
          isOnRoute: true,
          distanceToDestination: event.newRoute.distanceMeters,
          estimatedTimeInSeconds: event.newRoute.durationSeconds,
        ),
      );

      // Provide feedback that we're back on route
      _vibrationService.onRouteFeedback();
    }
  }

  void _onReroutingFailed(
    ReroutingFailed event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationRerouting) {
      emit(
        NavigationError(
          message: "Rerouting failed: ${event.reason}",
          isFatal: false,
        ),
      );
    }
  }

  void _onOffRoute(OffRoute event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Only update if we're currently marked as on route
      if (currentState.isOnRoute) {
        emit(
          currentState.copyWith(
            isOnRoute: false,
            currentPosition: event.position,
            lastUpdated: DateTime.now(),
          ),
        );

        // The vibration feedback is handled by the navigation service
      }
    }
  }

  void _onOnRoute(OnRoute event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Only update if we're currently marked as off route
      if (!currentState.isOnRoute) {
        emit(
          currentState.copyWith(
            isOnRoute: true,
            currentPosition: event.position,
            lastUpdated: DateTime.now(),
          ),
        );

        // The vibration feedback is handled by the navigation service
      }
    }
  }

  void _onDestinationReached(
    DestinationReached event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      emit(
        NavigationArrived(
          destination: currentState.destination,
          finalPosition: event.position,
          totalDistance: currentState.route.distanceMeters,
          totalDuration: currentState.route.durationSeconds,
        ),
      );

      // The vibration feedback is handled by the navigation service
    }
  }

  void _onApproachingCrossing(
    ApproachingCrossing event,
    Emitter<NavigationState> emit,
  ) {
    _vibrationService.crossingStreetFeedback();
  }

  void _onApproachingHazard(
    ApproachingHazard event,
    Emitter<NavigationState> emit,
  ) {
    _vibrationService.hazardWarningFeedback();
  }

  void _onRouteDeviation(RouteDeviation event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Update state to reflect deviation
      emit(
        currentState.copyWith(
          isOnRoute: false,
          currentPosition: event.position,
          lastUpdated: DateTime.now(),
        ),
      );

      // Check if we should trigger rerouting
      // This is now handled by the navigation service
    }
  }

  void _onNavigationErrorReceived(
    _NavigationErrorReceived event,
    Emitter<NavigationState> emit,
  ) {
    emit(NavigationError(message: event.message));
  }

  @override
  Future<void> close() {
    // Clean up subscriptions
    _statusSubscription?.cancel();
    _positionSubscription?.cancel();
    _deviationSubscription?.cancel();
    _upcomingTurnSubscription?.cancel();
    _destinationReachedSubscription?.cancel();
    _reroutingSubscription?.cancel();
    _errorSubscription?.cancel();

    // Stop navigation
    _navigationService.stopNavigation();

    return super.close();
  }
}

// Private event for internal error handling
class _NavigationErrorReceived extends NavigationEvent {
  final String message;
  const _NavigationErrorReceived(this.message);
}
