import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/route_information.dart';
import '../utils/navigation_utilities.dart';
import 'location_service.dart';
import 'mapping_service.dart';
import 'vibration_service.dart';
import 'turn_detection_service.dart';

enum NavigationStatus { idle, active, rerouting, arrived, error }

class NavigationMonitoringService {
  // Singleton pattern
  static final NavigationMonitoringService _instance =
      NavigationMonitoringService._internal();
  factory NavigationMonitoringService() => _instance;
  NavigationMonitoringService._internal();

  // Services
  final LocationService _locationService = LocationService();
  final MappingService _mappingService = MappingService();
  final VibrationService _vibrationService = VibrationService();
  final TurnDetectionService _turnDetectionService = TurnDetectionService();

  // Configuration
  static const double _routeDeviationThreshold = 25.0; // meters
  static const double _destinationReachedThreshold = 15.0; // meters
  static const double _approachingTurnThreshold = 50.0; // meters
  static const int _minReroutingInterval = 30; // seconds

  // State
  NavigationStatus _status = NavigationStatus.idle;
  RouteInformation? _currentRoute;
  LatLng? _currentPosition;
  RouteStep? _nextStep;
  DateTime? _lastReroutingTime;
  bool _isMonitoring = false;
  bool _isOnRoute = true;
  int? _distanceToDestination;
  int? _estimatedTimeRemaining;

  // Subscriptions
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<double>? _deviationSubscription;
  StreamSubscription<RouteStep>? _upcomingTurnSubscription;
  StreamSubscription<String>? _turnDirectionSubscription;

  // Stream controllers
  final _statusController = StreamController<NavigationStatus>.broadcast();
  final _positionUpdateController = StreamController<LatLng>.broadcast();
  final _routeDeviationController = StreamController<double>.broadcast();
  final _upcomingTurnController = StreamController<RouteStep>.broadcast();
  final _destinationReachedController = StreamController<LatLng>.broadcast();
  final _reroutingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Public streams
  Stream<NavigationStatus> get statusStream => _statusController.stream;
  Stream<LatLng> get positionStream => _positionUpdateController.stream;
  Stream<double> get deviationStream => _routeDeviationController.stream;
  Stream<RouteStep> get upcomingTurnStream => _upcomingTurnController.stream;
  Stream<LatLng> get destinationReachedStream =>
      _destinationReachedController.stream;
  Stream<bool> get reroutingStream => _reroutingController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters
  NavigationStatus get status => _status;
  RouteInformation? get currentRoute => _currentRoute;
  LatLng? get currentPosition => _currentPosition;
  RouteStep? get nextStep => _nextStep;
  bool get isMonitoring => _isMonitoring;
  bool get isOnRoute => _isOnRoute;
  int? get distanceToDestination => _distanceToDestination;
  int? get estimatedTimeRemaining => _estimatedTimeRemaining;

  // Start navigation monitoring with a specific route
  Future<bool> startNavigation(RouteInformation route) async {
    if (_isMonitoring) {
      await stopNavigation();
    }

    try {
      _currentRoute = route;
      _isOnRoute = true;
      _nextStep = null;
      _lastReroutingTime = null;

      // Ensure location service is running
      if (!_locationService.isTracking) {
        final success = await _locationService.startLocationUpdates();
        if (!success) {
          _reportError('Failed to start location updates for navigation');
          return false;
        }
      }

      // Subscribe to location updates
      _locationSubscription = _locationService.locationStream.listen(
        _handleLocationUpdate,
        onError: (error) {
          _reportError('Location error during navigation: $error');
        },
      );

      // Start mapping service route deviation monitoring
      await _mappingService.startDeviationMonitoring(
        thresholdMeters: _routeDeviationThreshold,
      );

      // Subscribe to route deviation events
      _deviationSubscription = _mappingService.routeDeviationStream.listen(
        _handleRouteDeviation,
        onError: (error) {
          _reportError('Deviation monitoring error: $error');
        },
      );

      // Start turn detection
      await _turnDetectionService.startTurnDetection(route);

      // Subscribe to turn notifications
      _upcomingTurnSubscription = _turnDetectionService.upcomingTurnStream
          .listen(
            _handleUpcomingTurn,
            onError: (error) {
              _reportError('Turn detection error: $error');
            },
          );

      _turnDirectionSubscription = _turnDetectionService.turnDirectionStream
          .listen(
            _handleTurnDirection,
            onError: (error) {
              _reportError('Turn direction error: $error');
            },
          );

      // Update status and notify listeners
      _isMonitoring = true;
      _updateStatus(NavigationStatus.active);

      // Initial feedback that navigation has started
      _vibrationService.onRouteFeedback();

      return true;
    } catch (e) {
      _reportError('Failed to start navigation: $e');
      return false;
    }
  }

  // Stop navigation and clean up resources
  Future<void> stopNavigation() async {
    _locationSubscription?.cancel();
    _deviationSubscription?.cancel();
    _upcomingTurnSubscription?.cancel();
    _turnDirectionSubscription?.cancel();

    _locationSubscription = null;
    _deviationSubscription = null;
    _upcomingTurnSubscription = null;
    _turnDirectionSubscription = null;

    _mappingService.stopDeviationMonitoring();
    _turnDetectionService.stopTurnDetection();
    _vibrationService.stopVibration();

    _isMonitoring = false;
    _currentRoute = null;
    _nextStep = null;
    _updateStatus(NavigationStatus.idle);
  }

  // Handle location updates during navigation
  void _handleLocationUpdate(Position position) {
    final newPosition = LatLng(position.latitude, position.longitude);
    _currentPosition = newPosition;
    _positionUpdateController.add(newPosition);

    // Skip further processing if not actively navigating
    if (_status != NavigationStatus.active || _currentRoute == null) return;

    // Check if destination reached
    if (_checkDestinationReached(newPosition)) return;

    // Update distance and time estimates
    _updateNavigationProgress(newPosition);
  }

  // Check if the user has reached their destination
  bool _checkDestinationReached(LatLng position) {
    if (_currentRoute == null) return false;

    final destPosition = _currentRoute!.destination.position;
    final distance = NavigationUtilities.calculateDistance(
      position,
      destPosition,
    );

    if (distance <= _destinationReachedThreshold) {
      _destinationReachedController.add(position);
      _handleDestinationReached(position);
      return true;
    }
    return false;
  }

  // Update navigation progress based on current position
  void _updateNavigationProgress(LatLng position) {
    if (_currentRoute == null) return;

    // Calculate remaining distance
    _distanceToDestination = _currentRoute!.getRemainingDistance(position);

    // Calculate remaining time (simple estimate)
    if (_distanceToDestination != null && _currentRoute!.durationSeconds > 0) {
      final progressRatio =
          1 - (_distanceToDestination! / _currentRoute!.distanceMeters);
      _estimatedTimeRemaining =
          (_currentRoute!.durationSeconds * (1 - progressRatio)).round();
    }

    // Find next upcoming turn if we don't have one already
    if (_nextStep == null) {
      _nextStep = _currentRoute!.getNextTurnAfter(position);
      if (_nextStep != null) {
        _upcomingTurnController.add(_nextStep!);
      }
    } else {
      // Check if we're approaching the turn
      final distanceToTurn = NavigationUtilities.calculateDistance(
        position,
        _nextStep!.startLocation,
      );

      if (distanceToTurn <= _approachingTurnThreshold) {
        _upcomingTurnController.add(_nextStep!);
      }

      // Check if we've passed the turn
      final bearingToTurn = NavigationUtilities.calculateBearing(
        position,
        _nextStep!.endLocation,
      );

      final currentBearing = position.heading;
      final bearingDiff = (bearingToTurn - currentBearing).abs() % 360;

      if (bearingDiff > 90 && distanceToTurn > _approachingTurnThreshold) {
        // We've likely passed this turn, find the next one
        _nextStep = _currentRoute!.getNextTurnAfter(position);
        if (_nextStep != null) {
          _upcomingTurnController.add(_nextStep!);
        }
      }
    }
  }

  // Handle route deviation events
  void _handleRouteDeviation(double deviation) {
    if (deviation > 0) {
      // We've deviated from the route
      if (_isOnRoute) {
        _isOnRoute = false;
        _vibrationService.wrongDirectionFeedback();
        _routeDeviationController.add(deviation);

        // Check if we should start rerouting
        if (_shouldStartRerouting()) {
          _startRerouting(deviation);
        }
      }
    } else if (!_isOnRoute) {
      // We're back on route
      _isOnRoute = true;
      _vibrationService.onRouteFeedback();
    }
  }

  // Determine if we should start rerouting
  bool _shouldStartRerouting() {
    // Don't reroute if we're already rerouting
    if (_status == NavigationStatus.rerouting) return false;

    // Don't reroute too frequently
    if (_lastReroutingTime != null) {
      final timeSinceLastRerouting = DateTime.now()
          .difference(_lastReroutingTime!)
          .inSeconds;
      if (timeSinceLastRerouting < _minReroutingInterval) return false;
    }

    return true;
  }

  // Start the rerouting process
  void _startRerouting(double deviationDistance) {
    if (_currentPosition == null) return;

    _lastReroutingTime = DateTime.now();
    _updateStatus(NavigationStatus.rerouting);
    _reroutingController.add(true);
    _vibrationService.recalculatingRouteFeedback();

    // In a real implementation, we would trigger route recalculation here
    // This would typically call a routing service and provide a new route
    // For now, we'll just simulate the process

    // Simulate successful rerouting after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_status == NavigationStatus.rerouting) {
        // In real implementation, we would use the new route
        // For now, just return to active state
        _updateStatus(NavigationStatus.active);
        _reroutingController.add(false);
        _isOnRoute = true;
        _vibrationService.onRouteFeedback();
      }
    });
  }

  // Handle upcoming turn notifications
  void _handleUpcomingTurn(RouteStep step) {
    _nextStep = step;

    // Only provide feedback if we're in active navigation
    if (_status == NavigationStatus.active) {
      // Play appropriate haptic feedback for this turn
      switch (step.turnDirection) {
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
    }
  }

  // Handle turn direction updates
  void _handleTurnDirection(String direction) {
    // This is handled in upcoming turn
  }

  // Handle reaching the destination
  void _handleDestinationReached(LatLng position) {
    _updateStatus(NavigationStatus.arrived);
    _vibrationService.destinationReachedFeedback();

    // Clean up resources, but don't reset everything immediately
    // to allow UI to show arrival information
    _mappingService.stopDeviationMonitoring();
    _turnDetectionService.stopTurnDetection();

    // Keep subscriptions active temporarily to capture final position updates
    Future.delayed(const Duration(seconds: 5), () {
      if (_status == NavigationStatus.arrived) {
        stopNavigation();
      }
    });
  }

  // Update the current navigation status
  void _updateStatus(NavigationStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  // Report errors during navigation
  void _reportError(String message) {
    debugPrint('Navigation error: $message');
    _errorController.add(message);

    if (_isMonitoring) {
      _updateStatus(NavigationStatus.error);
    }
  }

  // Dispose of resources
  void dispose() {
    stopNavigation();

    _statusController.close();
    _positionUpdateController.close();
    _routeDeviationController.close();
    _upcomingTurnController.close();
    _destinationReachedController.close();
    _reroutingController.close();
    _errorController.close();
  }
}

// Extension to add heading property to LatLng for navigation purposes
extension LatLngWithHeading on LatLng {
  double get heading => 0.0; // This would be populated from Position data
}
