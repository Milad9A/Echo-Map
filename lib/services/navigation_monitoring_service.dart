import 'dart:async';
import 'package:echo_map/models/hazard.dart' show Hazard;
import 'package:echo_map/models/street_crossing.dart' show StreetCrossing;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/route_information.dart';
import '../utils/navigation_utilities.dart';
import '../utils/route_progress_tracker.dart';
import 'location_service.dart';
import 'mapping_service.dart';
import 'vibration_service.dart';
import 'turn_detection_service.dart';
import '../services/crossing_detection_service.dart';
import '../services/hazard_service.dart';
import '../services/emergency_service.dart';

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
  final CrossingDetectionService _crossingDetectionService =
      CrossingDetectionService();
  final HazardService _hazardService = HazardService();
  final EmergencyService _emergencyService = EmergencyService();

  // Route progress tracker
  final RouteProgressTracker _progressTracker = RouteProgressTracker();

  // Configuration
  static const double _routeDeviationThreshold = 25.0; // meters
  static const double _destinationReachedThreshold = 15.0; // meters
  static const double _approachingTurnThreshold = 50.0; // meters
  static const int _minReroutingInterval = 30; // seconds
  static const int _routeFeedbackInterval = 10; // seconds
  static const int _maxOffRouteTimeBeforeRerouting = 15; // seconds

  // State
  NavigationStatus _status = NavigationStatus.idle;
  RouteInformation? _currentRoute;
  LatLng? _currentPosition;
  RouteStep? _nextStep;
  DateTime? _lastReroutingTime;
  DateTime? _lastRouteFeedbackTime;
  DateTime? _offRouteStartTime;
  bool _isMonitoring = false;
  bool _isOnRoute = true;
  int? _distanceToDestination;
  int? _estimatedTimeRemaining;
  double _routeCompletionPercentage = 0.0;
  double _currentSpeed = 0.0; // m/s

  // Subscriptions
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<double>? _deviationSubscription;
  StreamSubscription<TurnNotification>? _turnNotificationSubscription;

  // Stream controllers
  final _statusController = StreamController<NavigationStatus>.broadcast();
  final _positionUpdateController = StreamController<LatLng>.broadcast();
  final _routeDeviationController = StreamController<double>.broadcast();
  final _upcomingTurnController = StreamController<RouteStep>.broadcast();
  final _destinationReachedController = StreamController<LatLng>.broadcast();
  final _reroutingController = StreamController<bool>.broadcast();
  final _progressUpdateController =
      StreamController<NavigationProgress>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _crossingDetectedController =
      StreamController<StreetCrossing>.broadcast();
  final _hazardDetectedController = StreamController<Hazard>.broadcast();
  final _emergencyController = StreamController<EmergencyEvent>.broadcast();

  // Public streams
  Stream<NavigationStatus> get statusStream => _statusController.stream;
  Stream<LatLng> get positionStream => _positionUpdateController.stream;
  Stream<double> get deviationStream => _routeDeviationController.stream;
  Stream<RouteStep> get upcomingTurnStream => _upcomingTurnController.stream;
  Stream<LatLng> get destinationReachedStream =>
      _destinationReachedController.stream;
  Stream<bool> get reroutingStream => _reroutingController.stream;
  Stream<NavigationProgress> get progressStream =>
      _progressUpdateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<StreetCrossing> get crossingDetectedStream =>
      _crossingDetectedController.stream;
  Stream<Hazard> get hazardDetectedStream => _hazardDetectedController.stream;
  Stream<EmergencyEvent> get emergencyStream => _emergencyController.stream;

  // Getters
  NavigationStatus get status => _status;
  RouteInformation? get currentRoute => _currentRoute;
  LatLng? get currentPosition => _currentPosition;
  RouteStep? get nextStep => _nextStep;
  bool get isMonitoring => _isMonitoring;
  bool get isOnRoute => _isOnRoute;
  int? get distanceToDestination => _distanceToDestination;
  int? get estimatedTimeRemaining => _estimatedTimeRemaining;
  double get routeCompletionPercentage => _routeCompletionPercentage;

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
      _lastRouteFeedbackTime = null;
      _offRouteStartTime = null;
      _routeCompletionPercentage = 0.0;
      _currentSpeed = 0.0;

      // Configure and start the route progress tracker
      _progressTracker.configure(
        routeDeviationThresholdMeters: _routeDeviationThreshold,
        turnNotificationDistanceMeters: _approachingTurnThreshold,
      );
      _progressTracker.startTracking(route);

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
      _turnNotificationSubscription = _turnDetectionService
          .turnNotificationStream
          .listen(
            _handleTurnNotification,
            onError: (error) {
              _reportError('Turn notification error: $error');
            },
          );

      // Start crossing detection
      await _crossingDetectionService.initialize();
      await _crossingDetectionService.startMonitoring(route: route);

      // Start hazard detection
      await _hazardService.initialize();
      await _hazardService.startMonitoring(route: route);

      // Initialize emergency service
      await _emergencyService.initialize();

      // Subscribe to emergency events
      _setupEmergencyListener();

      // Set up listeners for crossing and hazard events
      _setupCrossingAndHazardListeners();

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

  // Set up listener for emergency events
  void _setupEmergencyListener() {
    _emergencyService.emergencyStream.listen((event) {
      // Forward emergency events to our stream
      _emergencyController.add(event);

      // Handle emergency based on action type
      _handleEmergency(event);
    });
  }

  // Handle emergency events
  void _handleEmergency(EmergencyEvent event) {
    switch (event.action) {
      case EmergencyAction.stop:
        _handleEmergencyStop(event);
        break;
      case EmergencyAction.reroute:
        _handleEmergencyReroute(event);
        break;
      case EmergencyAction.detour:
        _handleEmergencyDetour(event);
        break;
      case EmergencyAction.pause:
        _handleEmergencyPause(event);
        break;
      case EmergencyAction.alertUser:
        // Just forward to the stream, vibration handled by emergency service
        break;
      case EmergencyAction.slowDown:
        // Just forward to the stream, vibration handled by emergency service
        break;
    }
  }

  // Handle emergency stop
  void _handleEmergencyStop(EmergencyEvent event) {
    // Stop all navigation immediately
    _updateStatus(NavigationStatus.error);
    _isOnRoute = false;

    // Log the emergency stop
    _reportError('Emergency stop: ${event.description}');
  }

  // Handle emergency reroute
  Future<void> _handleEmergencyReroute(EmergencyEvent event) async {
    if (_currentRoute == null || _currentPosition == null) {
      _reportError('Cannot reroute: No active route or current position');
      return;
    }

    // Update status to rerouting
    _updateStatus(NavigationStatus.rerouting);
    _reroutingController.add(true);

    // Request emergency reroute
    final newRoute = await _emergencyService.requestEmergencyReroute(
      origin: _currentPosition!,
      destination: _currentRoute!.destination.position,
      reason: event.description,
    );

    if (newRoute != null) {
      // Successfully rerouted
      _currentRoute = newRoute;
      _isOnRoute = true;
      _updateStatus(NavigationStatus.active);
      _reroutingController.add(false);

      // Reset turn detection with new route
      _turnDetectionService.stopTurnDetection();
      await _turnDetectionService.startTurnDetection(newRoute);

      // Resolve the emergency
      _emergencyService.resolveEmergency(resolution: "Rerouted successfully");
    } else {
      // Failed to reroute
      _reportError('Failed to calculate emergency reroute');
      _updateStatus(NavigationStatus.error);
    }
  }

  // Handle emergency detour around a specific area
  Future<void> _handleEmergencyDetour(EmergencyEvent event) async {
    if (_currentRoute == null || _currentPosition == null) {
      _reportError('Cannot create detour: No active route or current position');
      return;
    }

    // Update status to rerouting
    _updateStatus(NavigationStatus.rerouting);
    _reroutingController.add(true);

    // If location is provided, add it as an area to avoid
    if (event.location != null) {
      _emergencyService.addAreaToAvoid(event.location!);
    }

    // Request emergency reroute with detour
    final newRoute = await _emergencyService.requestEmergencyReroute(
      origin: _currentPosition!,
      destination: _currentRoute!.destination.position,
      reason: "Detour: ${event.description}",
    );

    if (newRoute != null) {
      // Successfully created detour
      _currentRoute = newRoute;
      _isOnRoute = true;
      _updateStatus(NavigationStatus.active);
      _reroutingController.add(false);

      // Reset turn detection with new route
      _turnDetectionService.stopTurnDetection();
      await _turnDetectionService.startTurnDetection(newRoute);

      // Resolve the emergency
      _emergencyService.resolveEmergency(
        resolution: "Detour created successfully",
      );
    } else {
      // Failed to create detour
      _reportError('Failed to calculate emergency detour');
      _updateStatus(NavigationStatus.error);
    }
  }

  // Handle emergency pause
  void _handleEmergencyPause(EmergencyEvent event) {
    // Temporarily stop providing updates but don't clear the route
    _isMonitoring = false;
    _updateStatus(NavigationStatus.idle);

    // This is a temporary pause, so don't clear subscriptions
    // We'll need to add a resume method later
  }

  // Emergency stop from external call
  Future<void> emergencyStop(String reason) async {
    if (!_isMonitoring) return;

    await _emergencyService.initiateEmergencyStop(reason: reason);

    // Stop will be handled by the emergency event handler
  }

  // Stop navigation and clean up resources
  Future<void> stopNavigation() async {
    _locationSubscription?.cancel();
    _deviationSubscription?.cancel();
    _turnNotificationSubscription?.cancel();

    _locationSubscription = null;
    _deviationSubscription = null;
    _turnNotificationSubscription = null;

    _mappingService.stopDeviationMonitoring();
    _turnDetectionService.stopTurnDetection();
    _vibrationService.stopVibration();
    _progressTracker.stopTracking();
    _crossingDetectionService.stopMonitoring();
    _hazardService.stopMonitoring();

    // Clear any emergency states
    _emergencyService.resolveEmergency(resolution: "Navigation stopped");
    _emergencyService.clearAreasToAvoid();

    _isMonitoring = false;
    _currentRoute = null;
    _nextStep = null;
    _updateStatus(NavigationStatus.idle);
  }

  // Set up listeners for crossing and hazard events
  void _setupCrossingAndHazardListeners() {
    // Listen for crossing warnings
    _crossingDetectionService.crossingWarningStream.listen((warning) {
      // Forward to our stream
      _crossingDetectedController.add(warning.crossing);

      // Let the crossing service handle the vibration feedback
    });

    // Listen for hazard warnings
    _hazardService.hazardWarningStream.listen((warning) {
      // Forward to our stream
      _hazardDetectedController.add(warning.hazard);

      // Let the hazard service handle the vibration feedback
    });
  }

  // Handle location updates during navigation
  void _handleLocationUpdate(Position position) {
    final newPosition = LatLng(position.latitude, position.longitude);
    _currentPosition = newPosition;
    _positionUpdateController.add(newPosition);

    // Skip further processing if not actively navigating
    if (_status != NavigationStatus.active || _currentRoute == null) return;

    // Update the progress tracker
    _progressTracker.updatePosition(newPosition);

    // Calculate current speed (in m/s)
    _currentSpeed = position.speed;

    // Check if destination reached
    if (_checkDestinationReached(newPosition)) return;

    // Update navigation progress
    _updateNavigationProgress();

    // Provide periodic on-route feedback if needed
    _providePeriodicFeedback();

    // Update crossing detection
    if (_crossingDetectionService.isMonitoring) {
      _crossingDetectionService.updatePosition(newPosition);
    }

    // Update hazard detection
    if (_hazardService.isMonitoring) {
      _hazardService.updatePosition(newPosition);
    }
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

  // Provide periodic feedback when on route
  void _providePeriodicFeedback() {
    if (!_isOnRoute) return; // Only provide feedback when on route

    // Check if it's time for periodic feedback
    final now = DateTime.now();
    if (_lastRouteFeedbackTime == null ||
        now.difference(_lastRouteFeedbackTime!).inSeconds >=
            _routeFeedbackInterval) {
      // Provide a gentle on-route feedback
      _vibrationService.onRouteFeedback(
        intensity: VibrationService.lowIntensity,
      );
      _lastRouteFeedbackTime = now;
    }
  }

  // Update navigation progress based on current position
  void _updateNavigationProgress() {
    if (_currentRoute == null || _currentPosition == null) return;

    // Get progress data from the tracker
    _routeCompletionPercentage = _progressTracker.completedPercentage;
    _distanceToDestination = _progressTracker.remainingDistanceMeters;
    _estimatedTimeRemaining = _progressTracker.remainingTimeSeconds;
    _nextStep = _progressTracker.nextTurn;
    _isOnRoute = _progressTracker.isOnRoute;

    // Create and broadcast a progress update
    final progress = NavigationProgress(
      currentPosition: _currentPosition!,
      distanceToDestination: _distanceToDestination ?? 0,
      estimatedTimeRemaining: _estimatedTimeRemaining ?? 0,
      completionPercentage: _routeCompletionPercentage,
      isOnRoute: _isOnRoute,
      nextStep: _nextStep,
      distanceToNextStep: _progressTracker.distanceToNextTurnMeters,
      currentSpeed: _currentSpeed,
      timestamp: DateTime.now(),
    );

    _progressUpdateController.add(progress);
  }

  // Handle route deviation events
  void _handleRouteDeviation(double deviation) {
    // Broadcast the deviation
    _routeDeviationController.add(deviation);

    // Check if we're off route or back on route
    final isCurrentlyOnRoute = deviation <= _routeDeviationThreshold;

    if (!isCurrentlyOnRoute && _isOnRoute) {
      // Just went off route
      _isOnRoute = false;
      _offRouteStartTime = DateTime.now();
      _vibrationService.wrongDirectionFeedback();
    } else if (isCurrentlyOnRoute && !_isOnRoute) {
      // Just got back on route
      _isOnRoute = true;
      _offRouteStartTime = null;
      _vibrationService.onRouteFeedback();
    } else if (!isCurrentlyOnRoute && !_isOnRoute) {
      // Still off route, check if we should reroute
      if (_shouldStartRerouting()) {
        _startRerouting(deviation);
      }
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

    // Check if we've been off route long enough to justify rerouting
    if (_offRouteStartTime != null) {
      final timeOffRoute = DateTime.now()
          .difference(_offRouteStartTime!)
          .inSeconds;
      return timeOffRoute >= _maxOffRouteTimeBeforeRerouting;
    }

    return false;
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

  // Handle turn notifications
  void _handleTurnNotification(TurnNotification notification) {
    // Store the next step
    _nextStep = notification.step;

    // Forward to the upcoming turn stream
    _upcomingTurnController.add(notification.step);

    // Vibration feedback is handled by the turn detection service
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
    _progressUpdateController.close();
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
