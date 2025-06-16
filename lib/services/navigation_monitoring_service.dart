import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_information.dart';
import '../models/street_crossing.dart';
import '../models/hazard.dart';
import '../services/emergency_service.dart';
import '../services/vibration_service.dart';

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
  double _routeDeviationThreshold = 50.0;
  double _destinationReachedThreshold = 10.0;

  // Services (these would be injected in a real implementation)
  StreamSubscription<Position>? _locationSubscription;

  // Add vibration service
  final VibrationService _vibrationService = VibrationService();

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

  // Start location tracking
  Future<void> _startLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        ),
      ).listen(_handleLocationUpdate);
    } catch (e) {
      _errorController.add('Failed to start location tracking: $e');
    }
  }

  // Handle location updates
  void _handleLocationUpdate(Position position) {
    final newPosition = LatLng(position.latitude, position.longitude);
    _currentPosition = newPosition;
    _positionController.add(newPosition);

    if (_currentRoute == null) return;

    // Check route deviation
    _checkRouteDeviation(newPosition);

    // Check for upcoming turns
    _checkForUpcomingTurns(newPosition);

    // Check if destination reached
    _checkDestinationReached(newPosition);

    // Update distance and time estimates
    _updateEstimates(newPosition);

    // Provide regular "on route" feedback
    _provideRegularFeedback();
  }

  // Add regular feedback to keep user informed they're on track
  DateTime? _lastOnRouteFeedback;
  void _provideRegularFeedback() {
    final now = DateTime.now();

    // Only provide feedback if we're on route
    if (!_isOnRoute) return;

    // Provide feedback every 30 seconds
    if (_lastOnRouteFeedback == null ||
        now.difference(_lastOnRouteFeedback!).inSeconds >= 30) {
      _lastOnRouteFeedback = now;
      _vibrationService.onRouteFeedback();
    }
  }

  // Check if user has deviated from route
  void _checkRouteDeviation(LatLng position) {
    if (_currentRoute == null) return;

    // Simple distance calculation for demonstration
    final deviation = _calculateMinimumDistanceToRoute(position);

    final wasOnRoute = _isOnRoute;
    _isOnRoute = deviation <= _routeDeviationThreshold;

    // If deviation status changed
    if (wasOnRoute != _isOnRoute) {
      if (!_isOnRoute) {
        _deviationController.add(deviation);
        // Provide immediate vibration feedback for going off route
        _vibrationService.wrongDirectionFeedback();
      } else {
        // Back on route - provide positive feedback
        _vibrationService.onRouteFeedback();
      }
    }

    // Check if significant deviation requires rerouting
    if (deviation > _routeDeviationThreshold * 2) {
      _triggerRerouting(position, deviation);
    }
  }

  // Calculate minimum distance to route (simplified)
  double _calculateMinimumDistanceToRoute(LatLng position) {
    // This is a simplified implementation
    // In a real app, you'd calculate the distance to the route polyline
    return 0.0;
  }

  // Update distance and time estimates
  void _updateEstimates(LatLng position) {
    if (_currentRoute == null) return;

    // Calculate distance to destination
    _distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _currentRoute!.destination.position.latitude,
      _currentRoute!.destination.position.longitude,
    ).round();

    // Estimate time remaining (simplified calculation)
    // Assuming average speed of 5 km/h for walking
    const averageSpeed = 5.0; // km/h
    if (_distanceToDestination != null) {
      final distanceInKm = _distanceToDestination! / 1000.0;
      _estimatedTimeRemaining =
          (distanceInKm / averageSpeed * 3600).round(); // in seconds
    }
  }

  // Check if destination is reached
  void _checkDestinationReached(LatLng position) {
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

      // Provide destination reached feedback
      _vibrationService.destinationReachedFeedback();
    }
  }

  // Add method to handle approaching turns
  void _checkForUpcomingTurns(LatLng position) {
    if (_currentRoute == null || !_currentRoute!.hasSteps) return;

    // Find the next turn in the route
    for (final step in _currentRoute!.steps) {
      if (step.isTurn) {
        final distanceToTurn = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          step.startLocation.latitude,
          step.startLocation.longitude,
        );

        // If approaching a turn (within 50 meters)
        if (distanceToTurn <= 50 && distanceToTurn > 20) {
          _upcomingTurnController.add(step);
          _vibrationService.approachingTurnFeedback();
          break;
        }
        // If very close to turn (within 20 meters)
        else if (distanceToTurn <= 20) {
          // Provide specific turn direction feedback
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

  // Trigger rerouting
  void _triggerRerouting(LatLng position, double deviation) {
    _status = NavigationStatus.rerouting;
    _statusController.add(_status);
    _reroutingController.add(true);

    // In a real implementation, this would calculate a new route
    // For now, we'll simulate rerouting completion after a delay
    Timer(const Duration(seconds: 3), () {
      _status = NavigationStatus.active;
      _statusController.add(_status);
      _reroutingController.add(false);
      _isOnRoute = true;
    });
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
