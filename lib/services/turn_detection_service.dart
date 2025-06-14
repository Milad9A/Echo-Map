import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_information.dart';
import '../utils/navigation_utilities.dart';
import 'location_service.dart';
import 'mapping_service.dart';
import 'vibration_service.dart';

/// Service for detecting upcoming turns and providing appropriate notifications
class TurnDetectionService {
  // Singleton pattern
  static final TurnDetectionService _instance =
      TurnDetectionService._internal();
  factory TurnDetectionService() => _instance;
  TurnDetectionService._internal();

  // Services
  final LocationService _locationService = LocationService();
  final MappingService _mappingService = MappingService();
  final VibrationService _vibrationService = VibrationService();

  // Configuration
  /// Distance in meters to notify before a turn
  double _turnNotificationDistance = 50.0;

  /// Distance in meters for "approaching turn" notification
  double _approachingTurnDistance = 100.0;

  /// Minimum bearing change to consider as a turn
  double _minTurnAngle = 30.0;

  // State
  RouteInformation? _currentRoute;
  StreamSubscription<Position>? _positionSubscription;
  bool _isMonitoring = false;
  int _lastNotifiedStepIndex = -1;
  DateTime? _lastTurnNotificationTime;
  final _minTimeBetweenNotifications = const Duration(seconds: 5);

  // Stream controllers for external listeners
  final StreamController<RouteStep> _upcomingTurnController =
      StreamController<RouteStep>.broadcast();
  final StreamController<String> _turnDirectionController =
      StreamController<String>.broadcast();

  // Public getters
  Stream<RouteStep> get upcomingTurnStream => _upcomingTurnController.stream;
  Stream<String> get turnDirectionStream => _turnDirectionController.stream;
  bool get isMonitoring => _isMonitoring;
  RouteInformation? get currentRoute => _currentRoute;

  // Start monitoring for turns along a route
  Future<bool> startTurnDetection(RouteInformation route) async {
    if (_isMonitoring) {
      stopTurnDetection();
    }

    _currentRoute = route;
    _lastNotifiedStepIndex = -1;
    _lastTurnNotificationTime = null;

    try {
      // Ensure location service is running
      if (!_locationService.isTracking) {
        final success = await _locationService.startLocationUpdates();
        if (!success) {
          debugPrint('Failed to start location updates for turn detection');
          return false;
        }
      }

      // Subscribe to location updates
      _positionSubscription = _locationService.locationStream.listen(
        _checkForUpcomingTurns,
        onError: (error) {
          debugPrint('Error in turn detection: $error');
        },
      );

      _isMonitoring = true;
      return true;
    } catch (e) {
      debugPrint('Error starting turn detection: $e');
      return false;
    }
  }

  // Stop monitoring for turns
  void stopTurnDetection() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    _currentRoute = null;
    _lastNotifiedStepIndex = -1;
  }

  // Check for upcoming turns based on current position
  void _checkForUpcomingTurns(Position position) {
    if (_currentRoute == null || !_currentRoute!.hasSteps) return;

    try {
      final currentPosition = LatLng(position.latitude, position.longitude);

      // Find the closest route segment index
      final closestSegmentIndex = _mappingService.findClosestRouteSegmentIndex(
        currentPosition,
      );
      if (closestSegmentIndex < 0) return;

      // Find the next turn after this segment
      final nextTurn = _findNextTurn(closestSegmentIndex);
      if (nextTurn == null) return;

      // Calculate distance to the turn
      final distanceToTurn = NavigationUtilities.calculateDistance(
        currentPosition,
        nextTurn.startLocation,
      );

      // Check if we're approaching or at a turn
      if (distanceToTurn <= _turnNotificationDistance) {
        _notifyTurn(nextTurn);
      } else if (distanceToTurn <= _approachingTurnDistance) {
        _notifyApproachingTurn(nextTurn);
      }
    } catch (e) {
      debugPrint('Error checking for upcoming turns: $e');
    }
  }

  // Find the next turn step after the current segment
  RouteStep? _findNextTurn(int currentSegmentIndex) {
    if (_currentRoute == null || !_currentRoute!.hasSteps) return null;

    // Find the current step that corresponds to our segment
    RouteStep? currentStep;
    for (final step in _currentRoute!.steps) {
      // Find a step that contains our current segment
      final stepStartPoint = step.startLocation;
      final stepEndPoint = step.endLocation;

      // Check if our current segment is within this step
      // This is a simplification - in a real app you'd map route points to steps
      final routePoints = _mappingService.activeRoutePoints;
      if (currentSegmentIndex < routePoints.length - 1) {
        final segmentStart = routePoints[currentSegmentIndex];
        final segmentEnd = routePoints[currentSegmentIndex + 1];

        // Check if this segment is part of the current step
        // Simple check: if segment is between step start and end
        final distanceToStart1 = NavigationUtilities.calculateDistance(
          segmentStart,
          stepStartPoint,
        );
        final distanceToStart2 = NavigationUtilities.calculateDistance(
          segmentEnd,
          stepStartPoint,
        );
        final distanceToEnd1 = NavigationUtilities.calculateDistance(
          segmentStart,
          stepEndPoint,
        );
        final distanceToEnd2 = NavigationUtilities.calculateDistance(
          segmentEnd,
          stepEndPoint,
        );

        if ((distanceToStart1 < 50 || distanceToStart2 < 50) ||
            (distanceToEnd1 < 50 || distanceToEnd2 < 50)) {
          currentStep = step;
          break;
        }
      }
    }

    if (currentStep == null) return null;

    // Find the index of the current step
    final currentStepIndex = _currentRoute!.steps.indexOf(currentStep);

    // Look for the next step that has a significant turn
    for (int i = currentStepIndex + 1; i < _currentRoute!.steps.length; i++) {
      final nextStep = _currentRoute!.steps[i];

      // Check if this step involves a turn
      if (nextStep.maneuver.isNotEmpty &&
          nextStep.maneuver != 'straight' &&
          i != _lastNotifiedStepIndex) {
        return nextStep;
      }
    }

    return null;
  }

  // Notify the user they are approaching a turn
  void _notifyApproachingTurn(RouteStep turn) {
    // Avoid too frequent notifications
    if (_shouldThrottleNotification()) return;

    // Notify about approaching turn
    _vibrationService.approachingTurnFeedback();

    // Broadcast turn info to listeners
    _upcomingTurnController.add(turn);
    _turnDirectionController.add('approaching_${turn.turnDirection}');

    _lastTurnNotificationTime = DateTime.now();
  }

  // Notify the user they should turn now
  void _notifyTurn(RouteStep turn) {
    // Avoid too frequent notifications
    if (_shouldThrottleNotification()) return;

    // Find the index of this step
    final stepIndex = _currentRoute!.steps.indexOf(turn);
    if (stepIndex == _lastNotifiedStepIndex) return;

    // Play the appropriate turn vibration pattern
    switch (turn.turnDirection) {
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

    // Broadcast turn info to listeners
    _upcomingTurnController.add(turn);
    _turnDirectionController.add(turn.turnDirection);

    // Mark this step as notified
    _lastNotifiedStepIndex = stepIndex;
    _lastTurnNotificationTime = DateTime.now();
  }

  // Check if we should throttle notifications to avoid overwhelming the user
  bool _shouldThrottleNotification() {
    if (_lastTurnNotificationTime == null) return false;

    final timeSinceLastNotification = DateTime.now().difference(
      _lastTurnNotificationTime!,
    );

    return timeSinceLastNotification < _minTimeBetweenNotifications;
  }

  // Update configuration settings
  void configure({
    double? turnNotificationDistance,
    double? approachingTurnDistance,
    double? minTurnAngle,
  }) {
    if (turnNotificationDistance != null) {
      _turnNotificationDistance = turnNotificationDistance;
    }

    if (approachingTurnDistance != null) {
      _approachingTurnDistance = approachingTurnDistance;
    }

    if (minTurnAngle != null) {
      _minTurnAngle = minTurnAngle;
    }
  }

  // Dispose resources
  void dispose() {
    stopTurnDetection();
    _upcomingTurnController.close();
    _turnDirectionController.close();
  }
}
