import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_information.dart';
import '../../services/location_service.dart';
import '../../services/mapping_service.dart';
import '../../services/navigation_monitoring_service.dart';
import '../../services/vibration_service.dart';
import '../../services/routing_service.dart';
import '../../services/geocoding_service.dart';
import '../../models/street_crossing.dart';
import '../../models/hazard.dart';
import '../../services/emergency_service.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final VibrationService _vibrationService = VibrationService();
  final MappingService _mappingService = MappingService();
  final LocationService _locationService = LocationService();
  final NavigationMonitoringService _navigationService =
      NavigationMonitoringService();
  final RoutingService _routingService = RoutingService();
  final GeocodingService _geocodingService = GeocodingService();

  final EmergencyService _emergencyService = EmergencyService();

  // Subscriptions
  StreamSubscription<NavigationStatus>? _statusSubscription;
  StreamSubscription<LatLng>? _positionSubscription;
  StreamSubscription<double>? _deviationSubscription;
  StreamSubscription<RouteStep>? _upcomingTurnSubscription;
  StreamSubscription<LatLng>? _destinationReachedSubscription;
  StreamSubscription<bool>? _reroutingSubscription;
  StreamSubscription<String>? _errorSubscription;

  // Add new subscriptions
  StreamSubscription<StreetCrossing>? _crossingSubscription;
  StreamSubscription<Hazard>? _hazardSubscription;
  StreamSubscription<EmergencyEvent>? _emergencySubscription;

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

    // Add handlers for emergency events
    on<EmergencyStopRequested>(_onEmergencyStopRequested);
    on<EmergencyRerouteRequested>(_onEmergencyRerouteRequested);
    on<EmergencyDetourRequested>(_onEmergencyDetourRequested);
    on<EmergencyEventReceived>(_onEmergencyEventReceived);
    on<EmergencyResolved>(_onEmergencyResolved);

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
    _destinationReachedSubscription =
        _navigationService.destinationReachedStream.listen((position) {
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

    // Subscribe to crossing detected events
    _crossingSubscription = _navigationService.crossingDetectedStream.listen((
      crossing,
    ) {
      add(
        ApproachingCrossing(
          position: LatLng(
            crossing.position.latitude,
            crossing.position.longitude,
          ),
        ),
      );
    });

    // Subscribe to hazard detected events
    _hazardSubscription = _navigationService.hazardDetectedStream.listen((
      hazard,
    ) {
      add(
        ApproachingHazard(
          hazardType: hazard.type.toString(),
          position: hazard.position,
        ),
      );
    });

    // Subscribe to emergency events
    _emergencySubscription = _navigationService.emergencyStream.listen((event) {
      add(
        EmergencyEventReceived(
          type: event.type.toString(),
          action: event.action.toString(),
          description: event.description,
          location: event.location,
        ),
      );
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
      case NavigationStatus.paused:
        // Paused state is handled by pause event
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

      final originLatLng = LatLng(position.latitude, position.longitude);

      // Use geocoding to convert destination string to coordinates
      LatLng? destinationLatLng;

      try {
        final geocodingResults =
            await _geocodingService.geocodeAddress(event.destination);

        if (geocodingResults.isEmpty) {
          emit(NavigationError(
              message: "Destination '${event.destination}' not found"));
          return;
        }

        // Use the first (most relevant) result
        final bestResult = geocodingResults.first;
        destinationLatLng = bestResult.coordinates;

        // Validate the coordinates
        if (!_geocodingService.isValidCoordinate(destinationLatLng)) {
          emit(NavigationError(message: "Invalid destination coordinates"));
          return;
        }
      } catch (e) {
        emit(NavigationError(message: "Failed to find destination: $e"));
        return;
      }

      // Calculate route
      final route = await _routingService.calculateRoute(
        originLatLng,
        destinationLatLng,
        mode: TravelMode.walking,
      );

      if (route == null) {
        emit(NavigationError(
            message: "Couldn't calculate route to destination"));
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
  ) async {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Pause the navigation service
      await _navigationService.pauseNavigation();

      // Stop vibration feedback
      _vibrationService.stopVibration();

      // Emit paused state
      emit(
        NavigationPaused(
          destination: currentState.destination,
          currentPosition: currentState.currentPosition,
          route: currentState.route,
          estimatedTimeInSeconds: currentState.estimatedTimeInSeconds,
        ),
      );

      // Provide pause feedback
      _vibrationService.pauseNavigationFeedback();
    }
  }

  Future<void> _onResumeNavigation(
    ResumeNavigation event,
    Emitter<NavigationState> emit,
  ) async {
    if (state is NavigationPaused) {
      final currentState = state as NavigationPaused;

      // Resume the navigation service
      await _navigationService.resumeNavigation();

      emit(
        NavigationActive(
          destination: currentState.destination,
          currentPosition: currentState.currentPosition,
          route: currentState.route,
          estimatedTimeInSeconds: currentState.estimatedTimeInSeconds,
          isOnRoute: _navigationService.isOnRoute,
        ),
      );

      // Provide resume feedback
      _vibrationService.onRouteFeedback();
    }
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
      int? newEta = _navigationService.estimatedTimeRemaining;

      // Smooth random changes in ETA
      if (currentState.estimatedTimeInSeconds != null && newEta != null) {
        final alpha = 0.7;
        newEta = (alpha * currentState.estimatedTimeInSeconds! +
                (1 - alpha) * newEta)
            .round();
      }
      if (newEta != null && currentState.estimatedTimeInSeconds != null) {
        final oldEta = currentState.estimatedTimeInSeconds!;
        final diff = (newEta - oldEta).abs();
        // Clamp if difference > 3 minutes
        if (diff > 180) {
          newEta = ((oldEta + newEta) / 2).round();
        }
      }
      emit(
        currentState.copyWith(
          currentPosition: event.position,
          distanceToDestination: remainingDistance,
          estimatedTimeInSeconds: newEta,
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

      // Update UI to show rerouting status
      emit(
        NavigationRerouting(
          currentPosition: event.currentPosition,
          destination: currentState.destination,
          deviationDistance: event.deviationDistance,
        ),
      );

      // If we need to manually trigger rerouting here as well:
      if (_navigationService.status != NavigationStatus.rerouting) {
        // Get destination from current route
        final destination = currentState.route.destination.position;

        // Calculate a new route
        _routingService
            .calculateRoute(
          event.currentPosition,
          destination,
          mode: TravelMode.walking,
        )
            .then((newRoute) {
          if (newRoute != null) {
            add(ReroutingComplete(newRoute));
          } else {
            add(ReroutingFailed("Couldn't calculate a new route"));
          }
        }).catchError((error) {
          add(ReroutingFailed("Error: $error"));
        });
      }
    }
  }

  void _onReroutingComplete(
    ReroutingComplete event,
    Emitter<NavigationState> emit,
  ) {
    if (state is NavigationRerouting) {
      final currentPosition = _navigationService.currentPosition ??
          (state as NavigationRerouting).currentPosition;

      // Update the map with the new route
      _mappingService.clearPolylines();
      _mappingService.addPolyline(
        id: 'route',
        points: event.newRoute.polylinePoints,
        color: Colors.blue, // Make it visually distinct
      );

      // Update destination marker if needed
      _mappingService.clearMarkers();
      _mappingService.addMarker(
        id: 'origin',
        position: currentPosition,
        title: 'Current Location',
      );
      _mappingService.addMarker(
        id: 'destination',
        position: event.newRoute.destination.position,
        title: event.newRoute.destination.name,
      );

      // Resume active navigation with the new route
      emit(
        NavigationActive(
          destination: event.newRoute.destination.name,
          currentPosition: currentPosition,
          route: event.newRoute,
          isOnRoute: true,
          distanceToDestination: event.newRoute.distanceMeters,
          estimatedTimeInSeconds: event.newRoute.durationSeconds,
        ),
      );

      // Provide feedback that we're back on route
      _vibrationService.newRouteFeedback();

      // Show the entire new route on the map
      _mappingService.animateCameraToPosition(currentPosition, zoom: 15);
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

  // Handle emergency stop request
  Future<void> _onEmergencyStopRequested(
    EmergencyStopRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state is NavigationActive || state is NavigationRerouting) {
      // Request emergency stop from navigation service
      await _navigationService.emergencyStop(event.reason);

      // Update UI state
      emit(
        NavigationEmergency(
          emergencyType: 'STOP',
          description: event.reason,
          currentPosition: event.position ??
              (state is NavigationActive
                  ? (state as NavigationActive).currentPosition
                  : null),
          isResolvable: false, // Stop is final
          actionRequired: 'Navigation stopped due to emergency',
        ),
      );

      // Clear map displays
      _mappingService.clearPolylines();
      _vibrationService.stopVibration();
    }
  }

  // Handle emergency reroute request
  Future<void> _onEmergencyRerouteRequested(
    EmergencyRerouteRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state is NavigationActive) {
      // Show emergency state while rerouting
      emit(
        NavigationEmergency(
          emergencyType: 'REROUTE',
          description: event.reason,
          currentPosition: event.position,
          isResolvable: true,
          actionRequired: 'Calculating emergency route...',
        ),
      );

      try {
        // Trigger emergency in the service
        await _emergencyService.triggerEmergency(
          type: EmergencyType.userInitiated,
          action: EmergencyAction.reroute,
          description: event.reason,
          location: event.position,
        );

        // The navigation monitoring service will handle the actual rerouting
        // We'll get updates via the subscription to navigation service
      } catch (e) {
        emit(
          NavigationError(
            message: 'Failed to request emergency reroute: $e',
            isFatal: false,
          ),
        );
      }
    }
  }

  // Handle emergency detour request
  Future<void> _onEmergencyDetourRequested(
    EmergencyDetourRequested event,
    Emitter<NavigationState> emit,
  ) async {
    if (state is NavigationActive) {
      // Show emergency state while calculating detour
      emit(
        NavigationEmergency(
          emergencyType: 'DETOUR',
          description: event.reason,
          currentPosition: event.position,
          isResolvable: true,
          actionRequired: 'Calculating detour around hazard...',
        ),
      );

      try {
        // Trigger emergency in the service
        await _emergencyService.triggerEmergency(
          type: EmergencyType.hazardAhead,
          action: EmergencyAction.detour,
          description: event.reason,
          location: event.hazardLocation,
          metadata: {
            'currentPosition': {
              'latitude': event.position.latitude,
              'longitude': event.position.longitude,
            },
          },
        );

        // The navigation monitoring service will handle the actual detour
        // We'll get updates via the subscription to navigation service
      } catch (e) {
        emit(
          NavigationError(
            message: 'Failed to request emergency detour: $e',
            isFatal: false,
          ),
        );
      }
    }
  }

  // Handle received emergency events
  void _onEmergencyEventReceived(
    EmergencyEventReceived event,
    Emitter<NavigationState> emit,
  ) {
    // Convert string action back to enum value
    EmergencyAction action;
    try {
      action = EmergencyAction.values.firstWhere(
        (e) => e.toString() == 'EmergencyAction.${event.action}',
        orElse: () => EmergencyAction.alertUser,
      );
    } catch (_) {
      action = EmergencyAction.alertUser;
    }

    // Update UI based on emergency type and action
    if (action == EmergencyAction.stop) {
      emit(
        NavigationEmergency(
          emergencyType: event.type,
          description: event.description,
          currentPosition: event.location ??
              (state is NavigationActive
                  ? (state as NavigationActive).currentPosition
                  : null),
          isResolvable: false,
          actionRequired: 'Navigation stopped due to emergency',
        ),
      );
    } else if (action == EmergencyAction.reroute ||
        action == EmergencyAction.detour) {
      emit(
        NavigationEmergency(
          emergencyType: event.type,
          description: event.description,
          currentPosition: event.location,
          isResolvable: true,
          actionRequired: action == EmergencyAction.reroute
              ? 'Rerouting...'
              : 'Creating detour...',
        ),
      );
    } else if (action == EmergencyAction.pause) {
      emit(
        NavigationEmergency(
          emergencyType: event.type,
          description: event.description,
          currentPosition: event.location,
          isResolvable: true,
          actionRequired: 'Navigation paused. Tap to resume.',
        ),
      );
    }
    // For alert or slow down, we'd remain in the current state
    // but the vibration feedback would be handled by the emergency service
  }

  // Handle emergency resolution
  void _onEmergencyResolved(
    EmergencyResolved event,
    Emitter<NavigationState> emit,
  ) {
    // If we're in an emergency state, return to appropriate state
    if (state is NavigationEmergency) {
      if (_navigationService.status == NavigationStatus.active &&
          _navigationService.currentRoute != null &&
          _navigationService.currentPosition != null) {
        // Return to active navigation
        emit(
          NavigationActive(
            destination: _navigationService.currentRoute!.destination.name,
            currentPosition: _navigationService.currentPosition!,
            route: _navigationService.currentRoute!,
            isOnRoute: _navigationService.isOnRoute,
            distanceToDestination: _navigationService.distanceToDestination,
            estimatedTimeInSeconds: _navigationService.estimatedTimeRemaining,
          ),
        );
      } else {
        // If navigation is not active, return to idle state
        emit(NavigationIdle());
      }
    }
  }

  @override
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
    _crossingSubscription?.cancel();
    _hazardSubscription?.cancel();
    _emergencySubscription?.cancel();
    return super.close();
  }
}

// Private event for internal error handling
class _NavigationErrorReceived extends NavigationEvent {
  final String message;
  const _NavigationErrorReceived(this.message);
}
