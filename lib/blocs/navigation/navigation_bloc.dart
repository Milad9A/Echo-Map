import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import '../../models/route_information.dart';
import '../../services/location_service.dart';
import '../../services/mapping_service.dart';
import '../../services/turn_detection_service.dart';
import '../../services/vibration_service.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final VibrationService _vibrationService = VibrationService();
  final MappingService _mappingService = MappingService();
  final LocationService _locationService = LocationService();
  final TurnDetectionService _turnDetectionService = TurnDetectionService();

  StreamSubscription<double>? _deviationSubscription;
  StreamSubscription<String>? _turnDirectionSubscription;
  RouteInformation? _currentRoute;

  // Constants for navigation
  static const double _routeDeviationThreshold = 20.0; // meters
  static const double _destinationReachedThreshold = 15.0; // meters

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
    on<RouteDeviation>(_onRouteDeviation);
    on<StartNavigatingRoute>(_onStartNavigatingRoute);
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

  Future<void> _onStartNavigatingRoute(
    StartNavigatingRoute event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      _currentRoute = event.route;

      // Start location updates if not already active
      if (!_locationService.isTracking) {
        await _locationService.startLocationUpdates();
      }

      // Start monitoring route deviation
      await _mappingService.startDeviationMonitoring(
        thresholdMeters: _routeDeviationThreshold,
      );

      // Start turn detection
      await _turnDetectionService.startTurnDetection(event.route);

      // Subscribe to deviation notifications
      _deviationSubscription = _mappingService.routeDeviationStream.listen((
        deviation,
      ) {
        if (deviation > 0) {
          add(RouteDeviation(deviation));
        } else if (state is NavigationActive &&
            !(state as NavigationActive).isOnRoute) {
          add(OnRoute());
        }
      });

      // Subscribe to turn direction notifications
      _turnDirectionSubscription = _turnDetectionService.turnDirectionStream
          .listen((direction) {
            if (direction.startsWith('approaching_')) {
              final turnType = direction.substring('approaching_'.length);
              add(ApproachingTurn(turnType));
            }
          });

      // Initial state with origin and destination
      final origin = event.route.origin;
      final destination = event.route.destination;

      emit(
        NavigationActive(
          destination: destination.name,
          currentLatitude: origin.position.latitude,
          currentLongitude: origin.position.longitude,
          isOnRoute: true,
          distanceToDestination: event.route.distanceMeters,
          estimatedTimeInSeconds: event.route.durationSeconds,
        ),
      );

      // Initial on-route feedback
      _vibrationService.onRouteFeedback();
    } catch (e) {
      emit(NavigationError('Failed to start navigation: $e'));
    }
  }

  void _onStopNavigation(StopNavigation event, Emitter<NavigationState> emit) {
    _cleanupSubscriptions();
    _mappingService.stopDeviationMonitoring();
    _turnDetectionService.stopTurnDetection();
    _vibrationService.stopVibration();
    _currentRoute = null;
    emit(NavigationInitial());
  }

  void _onUpdateLocation(UpdateLocation event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Check if we've reached the destination
      if (_currentRoute != null) {
        final currentPosition = LatLng(event.latitude, event.longitude);
        final distanceToDestination = _currentRoute!.getRemainingDistance(
          currentPosition,
        );

        // Update state with new position and remaining distance
        emit(
          currentState.copyWith(
            currentLatitude: event.latitude,
            currentLongitude: event.longitude,
            distanceToDestination: distanceToDestination,
          ),
        );

        // Check if we've reached the destination
        final destinationPosition = _currentRoute!.destination.position;
        final directDistance = _calculateDistance(
          currentPosition,
          destinationPosition,
        );

        if (directDistance <= _destinationReachedThreshold) {
          add(ReachedDestination());
        }
      } else {
        // Just update position if no route is active
        emit(
          currentState.copyWith(
            currentLatitude: event.latitude,
            currentLongitude: event.longitude,
          ),
        );
      }
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
    _cleanupSubscriptions();
    _mappingService.stopDeviationMonitoring();
    _turnDetectionService.stopTurnDetection();
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

  void _onRouteDeviation(RouteDeviation event, Emitter<NavigationState> emit) {
    if (state is NavigationActive) {
      final currentState = state as NavigationActive;

      // Only process if currently on route to avoid duplicate notifications
      if (currentState.isOnRoute) {
        add(OffRoute());
      }
    }
  }

  // Helper method to clean up subscriptions
  void _cleanupSubscriptions() {
    _deviationSubscription?.cancel();
    _deviationSubscription = null;

    _turnDirectionSubscription?.cancel();
    _turnDirectionSubscription = null;
  }

  // Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters

    final lat1 = point1.latitude * (3.141592653589793 / 180);
    final lat2 = point2.latitude * (3.141592653589793 / 180);
    final dLat =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final dLon =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);
    final a =
        pow(sin(dLat / 2), 2) + pow(sin(dLon / 2), 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Future<void> close() {
    _cleanupSubscriptions();
    _mappingService.stopDeviationMonitoring();
    _turnDetectionService.stopTurnDetection();
    return super.close();
  }
}
