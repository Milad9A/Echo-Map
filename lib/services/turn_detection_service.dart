import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_information.dart';
import '../utils/route_progress_tracker.dart';
import 'location_service.dart';
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
  final VibrationService _vibrationService = VibrationService();

  // Route progress tracker
  final RouteProgressTracker _progressTracker = RouteProgressTracker();

  // Configuration
  /// Distance in meters to notify before a turn
  double _turnNotificationDistance = 50.0;

  /// Distance in meters for "approaching turn" notification
  double _approachingTurnDistance = 100.0;

  /// Distance in meters for "at turn" notification
  double _atTurnDistance = 20.0;

  // State
  RouteInformation? _currentRoute;
  StreamSubscription<Position>? _positionSubscription;
  bool _isMonitoring = false;
  int _lastNotifiedStepIndex = -1;
  DateTime? _lastTurnNotificationTime;
  TurnNotificationType? _lastNotificationType;
  final _minTimeBetweenNotifications = const Duration(seconds: 5);

  // Stream controllers for external listeners
  final StreamController<RouteStep> _upcomingTurnController =
      StreamController<RouteStep>.broadcast();
  final StreamController<String> _turnDirectionController =
      StreamController<String>.broadcast();
  final StreamController<TurnNotification> _turnNotificationController =
      StreamController<TurnNotification>.broadcast();

  // Public getters
  Stream<RouteStep> get upcomingTurnStream => _upcomingTurnController.stream;
  Stream<String> get turnDirectionStream => _turnDirectionController.stream;
  Stream<TurnNotification> get turnNotificationStream =>
      _turnNotificationController.stream;
  bool get isMonitoring => _isMonitoring;
  RouteInformation? get currentRoute => _currentRoute;
  RouteStep? get nextTurn => _progressTracker.nextTurn;
  int get distanceToNextTurn => _progressTracker.distanceToNextTurnMeters;

  // Start monitoring for turns along a route
  Future<bool> startTurnDetection(RouteInformation route) async {
    if (_isMonitoring) {
      stopTurnDetection();
    }

    _currentRoute = route;
    _lastNotifiedStepIndex = -1;
    _lastTurnNotificationTime = null;
    _lastNotificationType = null;

    try {
      // Configure the progress tracker
      _progressTracker.configure(
        turnNotificationDistanceMeters: _approachingTurnDistance,
        routeDeviationThresholdMeters: 25.0,
      );

      // Start tracking the route
      _progressTracker.startTracking(route);

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
        _processLocationUpdate,
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
    _progressTracker.stopTracking();
  }

  // Process location updates and check for turns
  void _processLocationUpdate(Position position) {
    if (!_isMonitoring || _currentRoute == null) return;

    try {
      final currentPosition = LatLng(position.latitude, position.longitude);

      // Update the progress tracker with the new position
      _progressTracker.updatePosition(currentPosition);

      // Check for turns based on the updated tracker state
      _checkForTurns(currentPosition);
    } catch (e) {
      debugPrint('Error processing location update for turn detection: $e');
    }
  }

  // Check for upcoming turns
  void _checkForTurns(LatLng currentPosition) {
    // Get the next turn from the progress tracker
    final nextTurn = _progressTracker.nextTurn;
    if (nextTurn == null) return;

    // Get the step index to check if we've already notified for this step
    final stepIndex = _currentRoute!.steps.indexOf(nextTurn);
    if (stepIndex < 0) return;

    // Get distance to the turn
    final distanceToTurn = _progressTracker.distanceToNextTurnMeters;

    // Determine the notification type based on distance
    TurnNotificationType notificationType;

    if (distanceToTurn <= _atTurnDistance) {
      notificationType = TurnNotificationType.atTurn;
    } else if (distanceToTurn <= _turnNotificationDistance) {
      notificationType = TurnNotificationType.approaching;
    } else if (distanceToTurn <= _approachingTurnDistance) {
      notificationType = TurnNotificationType.earlyWarning;
    } else {
      // Too far away, no notification needed yet
      return;
    }

    // Check if we should send a notification
    if (_shouldSendTurnNotification(stepIndex, notificationType)) {
      _sendTurnNotification(nextTurn, notificationType, distanceToTurn);
    }
  }

  // Determine if we should send a notification
  bool _shouldSendTurnNotification(int stepIndex, TurnNotificationType type) {
    // Always notify for new steps
    if (stepIndex != _lastNotifiedStepIndex) {
      return true;
    }

    // If it's the same step, check notification type
    if (type != _lastNotificationType) {
      // If we're progressing to a more urgent notification type, allow it
      if (_isMoreUrgentNotification(type)) {
        return true;
      }
    }

    // Check time throttling
    if (_lastTurnNotificationTime != null) {
      final timeSinceLastNotification = DateTime.now().difference(
        _lastTurnNotificationTime!,
      );

      if (timeSinceLastNotification < _minTimeBetweenNotifications) {
        return false;
      }
    }

    return true;
  }

  // Check if a notification type is more urgent than the last one
  bool _isMoreUrgentNotification(TurnNotificationType type) {
    if (_lastNotificationType == null) return true;

    // Order of urgency: earlyWarning < approaching < atTurn
    final typeValue = _getNotificationTypeValue(type);
    final lastTypeValue = _getNotificationTypeValue(_lastNotificationType!);

    return typeValue > lastTypeValue;
  }

  // Helper to get a numeric value for notification types to compare urgency
  int _getNotificationTypeValue(TurnNotificationType type) {
    switch (type) {
      case TurnNotificationType.earlyWarning:
        return 1;
      case TurnNotificationType.approaching:
        return 2;
      case TurnNotificationType.atTurn:
        return 3;
    }
  }

  // Send a turn notification
  void _sendTurnNotification(
    RouteStep turn,
    TurnNotificationType notificationType,
    int distanceMeters,
  ) {
    // Update tracking state
    _lastNotifiedStepIndex = _currentRoute!.steps.indexOf(turn);
    _lastTurnNotificationTime = DateTime.now();
    _lastNotificationType = notificationType;

    // Create a notification object
    final notification = TurnNotification(
      step: turn,
      type: notificationType,
      distanceMeters: distanceMeters,
      timestamp: _lastTurnNotificationTime!,
    );

    // Broadcast to streams
    _upcomingTurnController.add(turn);
    _turnDirectionController.add(
      '${notificationType.name}_${turn.turnDirection}',
    );
    _turnNotificationController.add(notification);

    // Provide haptic feedback based on the notification type and turn direction
    _provideTurnFeedback(turn, notificationType);
  }

  // Provide appropriate haptic feedback for a turn
  void _provideTurnFeedback(RouteStep turn, TurnNotificationType type) {
    switch (type) {
      case TurnNotificationType.earlyWarning:
        // Light feedback that a turn is coming up
        _vibrationService.approachingTurnFeedback(
          intensity: VibrationService.lowIntensity,
        );
        break;

      case TurnNotificationType.approaching:
        // Standard notification for approaching a turn
        switch (turn.turnDirection) {
          case 'left':
            _vibrationService.leftTurnFeedback(
              intensity: VibrationService.mediumIntensity,
            );
            break;
          case 'right':
            _vibrationService.rightTurnFeedback(
              intensity: VibrationService.mediumIntensity,
            );
            break;
          case 'uturn':
            _vibrationService.uTurnFeedback(
              intensity: VibrationService.mediumIntensity,
            );
            break;
          default:
            _vibrationService.approachingTurnFeedback(
              intensity: VibrationService.mediumIntensity,
            );
        }
        break;

      case TurnNotificationType.atTurn:
        // Stronger feedback that you need to turn now
        switch (turn.turnDirection) {
          case 'left':
            _vibrationService.leftTurnFeedback(
              intensity: VibrationService.highIntensity,
            );
            break;
          case 'right':
            _vibrationService.rightTurnFeedback(
              intensity: VibrationService.highIntensity,
            );
            break;
          case 'uturn':
            _vibrationService.uTurnFeedback(
              intensity: VibrationService.highIntensity,
            );
            break;
          default:
            _vibrationService.approachingTurnFeedback(
              intensity: VibrationService.highIntensity,
            );
        }
        break;
    }
  }

  // Update configuration settings
  void configure({
    double? turnNotificationDistance,
    double? approachingTurnDistance,
    double? atTurnDistance,
    double? minTurnAngle,
  }) {
    if (turnNotificationDistance != null) {
      _turnNotificationDistance = turnNotificationDistance;
    }

    if (approachingTurnDistance != null) {
      _approachingTurnDistance = approachingTurnDistance;
      // Update the progress tracker as well
      _progressTracker.configure(
        turnNotificationDistanceMeters: _approachingTurnDistance,
      );
    }

    if (atTurnDistance != null) {
      _atTurnDistance = atTurnDistance;
    }

    if (minTurnAngle != null) {}
  }

  // Dispose resources
  void dispose() {
    stopTurnDetection();
    _upcomingTurnController.close();
    _turnDirectionController.close();
    _turnNotificationController.close();
  }
}

/// Enum representing different types of turn notifications
enum TurnNotificationType {
  /// Early warning that a turn is coming up (furthest distance)
  earlyWarning,

  /// Approaching a turn (medium distance)
  approaching,

  /// At a turn (closest distance, turn now)
  atTurn,
}

/// Class representing a turn notification
class TurnNotification {
  final RouteStep step;
  final TurnNotificationType type;
  final int distanceMeters;
  final DateTime timestamp;

  TurnNotification({
    required this.step,
    required this.type,
    required this.distanceMeters,
    required this.timestamp,
  });

  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String get typeText {
    switch (type) {
      case TurnNotificationType.earlyWarning:
        return 'Upcoming';
      case TurnNotificationType.approaching:
        return 'Approaching';
      case TurnNotificationType.atTurn:
        return 'Turn Now';
    }
  }
}
