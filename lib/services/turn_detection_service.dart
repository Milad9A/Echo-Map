import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_information.dart';
import '../utils/navigation_utilities.dart';

class TurnDetectionService {
  static final TurnDetectionService _instance =
      TurnDetectionService._internal();
  factory TurnDetectionService() => _instance;
  TurnDetectionService._internal();

  // Stream controllers
  final _upcomingTurnController = StreamController<RouteStep>.broadcast();
  final _turnCompletedController = StreamController<RouteStep>.broadcast();

  // Public streams
  Stream<RouteStep> get upcomingTurnStream => _upcomingTurnController.stream;
  Stream<RouteStep> get turnCompletedStream => _turnCompletedController.stream;

  // State
  RouteInformation? _currentRoute;
  RouteStep? _nextTurn;
  bool _turnNotificationSent = false;
  int _currentStepIndex = 0;

  // Configuration
  double _turnNotificationDistance = 50.0; // meters

  // Initialize the service
  Future<void> initialize() async {
    // Initialize any required dependencies
  }

  // Start monitoring for turns
  Future<bool> startMonitoring({RouteInformation? route}) async {
    if (route != null) {
      _currentRoute = route;
      _findNextTurn();
    }
    return true;
  }

  // Stop monitoring
  void stopMonitoring() {
    _currentRoute = null;
    _nextTurn = null;
    _turnNotificationSent = false;
    _currentStepIndex = 0;
  }

  // Update current position and check for turns
  void updatePosition(LatLng position) {
    if (_currentRoute == null) return;

    // Update current step based on position
    _updateCurrentStep(position);

    // Check for upcoming turns
    _checkForUpcomingTurn(position);

    // Check if current turn was completed
    _checkTurnCompletion(position);
  }

  // Find the next turn in the route
  void _findNextTurn() {
    if (_currentRoute == null || !_currentRoute!.hasSteps) return;

    // Look for the next turn starting from current step
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      if (step.isTurn) {
        _nextTurn = step;
        _turnNotificationSent = false;
        return;
      }
    }

    // No more turns found
    _nextTurn = null;
  }

  // Update current step based on position
  void _updateCurrentStep(LatLng position) {
    if (_currentRoute == null || !_currentRoute!.hasSteps) return;

    // Find the closest step to current position
    int closestStepIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];

      // Calculate distance to step start
      final distanceToStart = NavigationUtilities.calculateDistance(
        position,
        step.startLocation,
      );

      // Calculate distance to step end
      final distanceToEnd = NavigationUtilities.calculateDistance(
        position,
        step.endLocation,
      );

      final minStepDistance =
          distanceToStart < distanceToEnd ? distanceToStart : distanceToEnd;

      if (minStepDistance < minDistance) {
        minDistance = minStepDistance;
        closestStepIndex = i;
      }
    }

    // Update current step if it changed
    if (closestStepIndex != _currentStepIndex) {
      _currentStepIndex = closestStepIndex;

      // Find next turn after current step
      _findNextTurn();
    }
  }

  // Check for upcoming turns
  void _checkForUpcomingTurn(LatLng position) {
    if (_nextTurn == null || _turnNotificationSent) return;

    final distanceToTurn = NavigationUtilities.calculateDistance(
      position,
      _nextTurn!.startLocation,
    );

    // Notify if within notification distance
    if (distanceToTurn <= _turnNotificationDistance) {
      _upcomingTurnController.add(_nextTurn!);
      _turnNotificationSent = true;
    }
  }

  // Check if current turn was completed
  void _checkTurnCompletion(LatLng position) {
    if (_nextTurn == null) return;

    // Check if we've passed the turn end point
    final distanceToTurnEnd = NavigationUtilities.calculateDistance(
      position,
      _nextTurn!.endLocation,
    );

    // If we're close to the turn end, consider it completed
    if (distanceToTurnEnd <= 10.0) {
      // 10 meter threshold
      _turnCompletedController.add(_nextTurn!);

      // Find the next turn
      _findNextTurn();
    }
  }

  // Configure notification distance
  void configure({double? turnNotificationDistance}) {
    if (turnNotificationDistance != null) {
      _turnNotificationDistance = turnNotificationDistance;
    }
  }

  // Dispose resources
  void dispose() {
    stopMonitoring();
    _upcomingTurnController.close();
    _turnCompletedController.close();
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
