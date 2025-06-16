import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_information.dart';
import '../models/street_crossing.dart';
import '../models/hazard.dart';
import '../services/emergency_service.dart';
import '../services/vibration_service.dart';
import '../services/routing_service.dart';

enum NavigationStatus {
  idle,
  active,
  paused, // Add paused status
  rerouting,
  arrived,
  error,
}

class NavigationMonitoringService {
  static final NavigationMonitoringService _instance =
      NavigationMonitoringService._internal();
  factory NavigationMonitoringService() => _instance;
  NavigationMonitoringService._internal();

  // Stream controllers
  final _statusController = StreamController<NavigationStatus>.broadcast();
  final _positionController = StreamController<LatLng>.broadcast();
  final _deviationController = StreamController<double>.broadcast();
  final _upcomingTurnController = StreamController<RouteStep>.broadcast();
  final _destinationReachedController = StreamController<LatLng>.broadcast();
  final _reroutingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _crossingDetectedController =
      StreamController<StreetCrossing>.broadcast();
  final _hazardDetectedController = StreamController<Hazard>.broadcast();
  final _emergencyController = StreamController<EmergencyEvent>.broadcast();

  // Public streams
  Stream<NavigationStatus> get statusStream => _statusController.stream;
  Stream<LatLng> get positionStream => _positionController.stream;
  Stream<double> get deviationStream => _deviationController.stream;
  Stream<RouteStep> get upcomingTurnStream => _upcomingTurnController.stream;
  Stream<LatLng> get destinationReachedStream =>
      _destinationReachedController.stream;
  Stream<bool> get reroutingStream => _reroutingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<StreetCrossing> get crossingDetectedStream =>
      _crossingDetectedController.stream;
  Stream<Hazard> get hazardDetectedStream => _hazardDetectedController.stream;
  Stream<EmergencyEvent> get emergencyStream => _emergencyController.stream;

  // State
  NavigationStatus _status = NavigationStatus.idle;
  RouteInformation? _currentRoute;
  LatLng? _currentPosition;
  bool _isOnRoute = true;
  int? _distanceToDestination;
  int? _estimatedTimeRemaining;
  RouteStep? _nextStep;
  bool _isPaused = false; // Add pause state tracking

  // Configuration
  double _routeDeviationThreshold =
      15.0; // Reduced from 50.0 for more precision
  double _destinationReachedThreshold =
      5.0; // Reduced from 10.0 for more precision

  // Services (these would be injected in a real implementation)
  StreamSubscription<Position>? _locationSubscription;

  // Add vibration service
  final VibrationService _vibrationService = VibrationService();

  // Add more precise tracking variables
  DateTime? _lastPositionUpdate;
  LatLng? _previousPosition;
  double _currentSpeed = 0.0;
  final List<LatLng> _recentPositions =
      []; // Track recent positions for smoothing
  int _consecutiveOnRouteUpdates = 0;
  int _consecutiveOffRouteUpdates = 0;

  // Getters
  NavigationStatus get status => _status;
  RouteInformation? get currentRoute => _currentRoute;
  LatLng? get currentPosition => _currentPosition;
  bool get isOnRoute => _isOnRoute;
  int? get distanceToDestination => _distanceToDestination;
  int? get estimatedTimeRemaining => _estimatedTimeRemaining;
  RouteStep? get nextStep => _nextStep;

  // Start navigation monitoring
  Future<bool> startNavigation(RouteInformation route) async {
    try {
      _currentRoute = route;
      _status = NavigationStatus.active;
      _statusController.add(_status);

      // Start location updates
      await _startLocationTracking();

      return true;
    } catch (e) {
      _errorController.add('Failed to start navigation: $e');
      return false;
    }
  }

  // Start location tracking with higher precision
  Future<void> _startLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, // Use best accuracy
          distanceFilter: 1, // Update every meter
          timeLimit: Duration(seconds: 5), // Faster timeout
        ),
      ).listen(_handleLocationUpdate);
    } catch (e) {
      _errorController.add('Failed to start location tracking: $e');
    }
  }

  // Enhanced location update handling
  void _handleLocationUpdate(Position position) {
    final newPosition = LatLng(position.latitude, position.longitude);
    final now = DateTime.now();

    // Calculate speed and movement
    if (_previousPosition != null && _lastPositionUpdate != null) {
      final distance = Geolocator.distanceBetween(
        _previousPosition!.latitude,
        _previousPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      final timeDiff =
          now.difference(_lastPositionUpdate!).inMilliseconds / 1000.0;
      if (timeDiff > 0) {
        _currentSpeed = distance / timeDiff; // meters per second
      }
    }

    _currentPosition = newPosition;
    _previousPosition = newPosition;
    _lastPositionUpdate = now;

    // Add to recent positions for smoothing (keep last 5 positions)
    _recentPositions.add(newPosition);
    if (_recentPositions.length > 5) {
      _recentPositions.removeAt(0);
    }

    _positionController.add(newPosition);

    if (_currentRoute == null) return;

    // Check route deviation with enhanced precision
    _checkRouteDeviationPrecise(newPosition);

    // Check for upcoming turns with better accuracy
    _checkForUpcomingTurnsPrecise(newPosition);

    // Check if destination reached with more precision
    _checkDestinationReachedPrecise(newPosition);

    // Update distance and time estimates more frequently
    _updateEstimatesPrecise(newPosition);

    // Provide more frequent feedback
    _provideEnhancedFeedback();
  }

  // Enhanced route deviation checking
  void _checkRouteDeviationPrecise(LatLng position) {
    if (_currentRoute == null) return;

    // Use average of recent positions for smoother detection
    LatLng smoothedPosition = position;
    if (_recentPositions.length >= 3) {
      double avgLat =
          _recentPositions.map((p) => p.latitude).reduce((a, b) => a + b) /
              _recentPositions.length;
      double avgLng =
          _recentPositions.map((p) => p.longitude).reduce((a, b) => a + b) /
              _recentPositions.length;
      smoothedPosition = LatLng(avgLat, avgLng);
    }

    // Calculate deviation from route
    final deviation = _calculatePreciseDistanceToRoute(smoothedPosition);

    final wasOnRoute = _isOnRoute;
    final currentlyOnRoute = deviation <= _routeDeviationThreshold;

    // Use consecutive updates to reduce false positives
    if (currentlyOnRoute) {
      _consecutiveOnRouteUpdates++;
      _consecutiveOffRouteUpdates = 0;

      if (_consecutiveOnRouteUpdates >= 2) {
        // Require 2 consecutive updates
        _isOnRoute = true;
      }
    } else {
      _consecutiveOffRouteUpdates++;
      _consecutiveOnRouteUpdates = 0;

      if (_consecutiveOffRouteUpdates >= 3) {
        // Require 3 consecutive updates to avoid false alarms
        _isOnRoute = false;
      }
    }

    // If deviation status changed
    if (wasOnRoute != _isOnRoute) {
      if (!_isOnRoute) {
        _deviationController.add(deviation);
        _vibrationService.wrongDirectionFeedback();
      } else {
        _vibrationService.onRouteFeedback();
      }
    }

    // Check if significant deviation requires rerouting
    if (deviation > _routeDeviationThreshold * 3) {
      // Increased threshold for rerouting
      _triggerRerouting(position, deviation);
    }
  }

  // More precise distance to route calculation
  double _calculatePreciseDistanceToRoute(LatLng position) {
    if (_currentRoute == null || _currentRoute!.polylinePoints.isEmpty) {
      return 0.0;
    }

    double minDistance = double.infinity;

    // Check distance to each segment of the route
    for (int i = 0; i < _currentRoute!.polylinePoints.length - 1; i++) {
      final segmentStart = _currentRoute!.polylinePoints[i];
      final segmentEnd = _currentRoute!.polylinePoints[i + 1];

      // Project point onto the line segment
      final projectedPoint =
          _projectPointOnSegment(position, segmentStart, segmentEnd);
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        projectedPoint.latitude,
        projectedPoint.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  // Project point onto line segment
  LatLng _projectPointOnSegment(
      LatLng point, LatLng segmentStart, LatLng segmentEnd) {
    final double x = point.longitude;
    final double y = point.latitude;
    final double x1 = segmentStart.longitude;
    final double y1 = segmentStart.latitude;
    final double x2 = segmentEnd.longitude;
    final double y2 = segmentEnd.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double segmentLengthSquared = dx * dx + dy * dy;

    if (segmentLengthSquared == 0) {
      return segmentStart; // Segment is a point
    }

    final double t = ((x - x1) * dx + (y - y1) * dy) / segmentLengthSquared;
    final double clampedT = t.clamp(0.0, 1.0);

    return LatLng(
      y1 + clampedT * dy,
      x1 + clampedT * dx,
    );
  }

  // Enhanced turn detection
  void _checkForUpcomingTurnsPrecise(LatLng position) {
    if (_currentRoute == null || !_currentRoute!.hasSteps) return;

    // Find the next turn in the route with better precision
    for (final step in _currentRoute!.steps) {
      if (step.isTurn) {
        final distanceToTurn = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          step.startLocation.latitude,
          step.startLocation.longitude,
        );

        // Adjust notification distance based on speed
        double notificationDistance = 30.0; // Base distance
        if (_currentSpeed > 1.5) {
          // If moving faster than walking pace
          notificationDistance = 50.0;
        } else if (_currentSpeed < 0.5) {
          // If moving very slowly
          notificationDistance = 15.0;
        }

        // If approaching a turn
        if (distanceToTurn <= notificationDistance && distanceToTurn > 10) {
          _upcomingTurnController.add(step);
          _vibrationService.approachingTurnFeedback();
          break;
        }
        // If very close to turn
        else if (distanceToTurn <= 10) {
          if (step.maneuver.contains('left')) {
            _vibrationService.leftTurnFeedback();
          } else if (step.maneuver.contains('right')) {
            _vibrationService.rightTurnFeedback();
          }
          break;
        }
      }
    }
  }

  // More precise destination checking
  void _checkDestinationReachedPrecise(LatLng position) {
    if (_currentRoute == null) return;

    final distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _currentRoute!.destination.position.latitude,
      _currentRoute!.destination.position.longitude,
    );

    if (distanceToDestination <= _destinationReachedThreshold) {
      _status = NavigationStatus.arrived;
      _statusController.add(_status);
      _destinationReachedController.add(position);
      _vibrationService.destinationReachedFeedback();
    }
  }

  // Enhanced estimates with real-time calculation
  void _updateEstimatesPrecise(LatLng position) {
    if (_currentRoute == null) return;

    // Calculate distance to destination more precisely
    _distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _currentRoute!.destination.position.latitude,
      _currentRoute!.destination.position.longitude,
    ).round();

    // Calculate remaining time based on current speed and route
    if (_currentSpeed > 0.1) {
      // Only if we're moving
      _estimatedTimeRemaining =
          (_distanceToDestination! / _currentSpeed).round();
    } else {
      // Fallback to route-based estimation
      const averageWalkingSpeed = 1.4; // m/s
      _estimatedTimeRemaining =
          (_distanceToDestination! / averageWalkingSpeed).round();
    }
  }

  // Enhanced feedback system
  DateTime? _lastOnRouteFeedback;
  void _provideEnhancedFeedback() {
    final now = DateTime.now();

    // Only provide feedback if we're on route and moving
    if (!_isOnRoute || _currentSpeed < 0.2) return;

    // Adjust feedback frequency based on speed and situation
    int feedbackInterval = 30; // Default 30 seconds

    if (_currentSpeed < 0.5) {
      feedbackInterval = 45; // Less frequent when moving slowly
    } else if (_currentSpeed > 2.0) {
      feedbackInterval = 20; // More frequent when moving fast
    }

    if (_lastOnRouteFeedback == null ||
        now.difference(_lastOnRouteFeedback!).inSeconds >= feedbackInterval) {
      _lastOnRouteFeedback = now;
      _vibrationService.onRouteFeedback(
          intensity: VibrationService.lowIntensity);
    }
  }

  // Trigger rerouting
  void _triggerRerouting(LatLng position, double deviation) {
    if (_status == NavigationStatus.rerouting) return; // Already rerouting

    _status = NavigationStatus.rerouting;
    _statusController.add(_status);
    _reroutingController.add(true);

    // Provide haptic feedback to indicate rerouting
    _vibrationService.wrongDirectionFeedback();

    // Get the routing service to calculate a new route
    final routingService = RoutingService();

    // If we have a current route, use its destination
    if (_currentRoute != null) {
      final destination = _currentRoute!.destination.position;

      debugPrint('Recalculating route from current position to destination');

      routingService
          .calculateRoute(
        position,
        destination,
        mode: TravelMode.walking,
      )
          .then((newRoute) {
        if (newRoute != null) {
          // Update the current route
          _currentRoute = newRoute;

          // Reset route state
          _isOnRoute = true;
          _consecutiveOffRouteUpdates = 0;

          // Update navigation state
          _status = NavigationStatus.active;
          _statusController.add(_status);

          // Provide feedback that we're back on route
          _vibrationService.newRouteFeedback();

          debugPrint('Rerouting successful - new route calculated');
        } else {
          // Failed to calculate new route
          debugPrint('Failed to calculate new route');
          _errorController.add('Unable to calculate a new route');

          // Return to active state but still off route
          _status = NavigationStatus.active;
          _statusController.add(_status);
        }

        // Signal that rerouting has finished (success or failure)
        _reroutingController.add(false);
      }).catchError((error) {
        debugPrint('Error calculating new route: $error');
        _errorController.add('Error calculating new route: $error');

        // Return to active state but still off route
        _status = NavigationStatus.active;
        _statusController.add(_status);
        _reroutingController.add(false);
      });
    } else {
      // No current route to recalculate
      debugPrint('Cannot reroute - no current route available');
      _errorController.add('Cannot reroute - no current route available');

      // Return to idle status
      _status = NavigationStatus.idle;
      _statusController.add(_status);
      _reroutingController.add(false);
    }
  }

  // Pause navigation
  Future<void> pauseNavigation() async {
    if (_status != NavigationStatus.active) return;

    _isPaused = true;
    _status = NavigationStatus.paused;
    _statusController.add(_status);

    // Pause location updates but keep the route data
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    debugPrint('Navigation paused');
  }

  // Resume navigation
  Future<void> resumeNavigation() async {
    if (_status != NavigationStatus.paused || _currentRoute == null) return;

    _isPaused = false;
    _status = NavigationStatus.active;
    _statusController.add(_status);

    // Resume location tracking
    await _startLocationTracking();

    debugPrint('Navigation resumed');
  }

  // Check if navigation is paused
  bool get isPaused => _isPaused;

  // Stop navigation
  Future<void> stopNavigation() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _currentRoute = null;
    _currentPosition = null;
    _nextStep = null;
    _isOnRoute = true;
    _distanceToDestination = null;
    _estimatedTimeRemaining = null;
    _isPaused = false; // Reset pause state

    _status = NavigationStatus.idle;
    _statusController.add(_status);
  }

  // Emergency stop
  Future<void> emergencyStop(String reason) async {
    debugPrint('Emergency stop requested: $reason');
    await stopNavigation();
  }

  // Configure thresholds
  void configure({
    double? routeDeviationThreshold,
    double? destinationReachedThreshold,
    double? turnNotificationDistance,
  }) {
    if (routeDeviationThreshold != null) {
      _routeDeviationThreshold = routeDeviationThreshold;
    }
    if (destinationReachedThreshold != null) {
      _destinationReachedThreshold = destinationReachedThreshold;
    }
  }

  // Dispose of resources
  void dispose() {
    stopNavigation();

    _statusController.close();
    _positionController.close();
    _deviationController.close();
    _upcomingTurnController.close();
    _destinationReachedController.close();
    _reroutingController.close();
    _errorController.close();
    _crossingDetectedController.close();
    _hazardDetectedController.close();
    _emergencyController.close();
  }
}

/// Class representing navigation progress data
class NavigationProgress {
  final LatLng currentPosition;
  final int distanceToDestination;
  final int estimatedTimeRemaining;
  final double completionPercentage;
  final bool isOnRoute;
  final RouteStep? nextStep;
  final int distanceToNextStep;
  final double currentSpeed;
  final DateTime timestamp;

  NavigationProgress({
    required this.currentPosition,
    required this.distanceToDestination,
    required this.estimatedTimeRemaining,
    required this.completionPercentage,
    required this.isOnRoute,
    this.nextStep,
    required this.distanceToNextStep,
    required this.currentSpeed,
    required this.timestamp,
  });

  String get distanceText {
    if (distanceToDestination < 1000) {
      return '$distanceToDestination m';
    } else {
      final km = distanceToDestination / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String get timeText {
    final minutes = (estimatedTimeRemaining / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  String get percentageText {
    return '${(completionPercentage * 100).toStringAsFixed(0)}%';
  }

  String get speedText {
    return '${(currentSpeed * 3.6).toStringAsFixed(1)} km/h';
  }
}
