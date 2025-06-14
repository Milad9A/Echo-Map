import 'dart:math' as math show min;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_information.dart';
import '../utils/navigation_utilities.dart';

/// A utility class to track a user's progress along a navigation route
class RouteProgressTracker {
  // Current route information
  RouteInformation? _route;

  // Position tracking
  LatLng? _lastPosition;
  int _lastStepIndex = 0;

  // Progress metrics
  double _completedPercentage = 0.0;
  int _remainingDistanceMeters = 0;
  int _remainingTimeSeconds = 0;
  bool _isOnRoute = true;
  double _routeDeviationMeters = 0.0;

  // Turn prediction
  RouteStep? _nextTurn;
  int _distanceToNextTurnMeters = 0;

  // Route status
  bool _isNavigating = false;
  DateTime? _startTime;
  DateTime? _lastUpdateTime;

  // Configuration
  double _routeDeviationThresholdMeters = 20.0;
  double _turnNotificationDistanceMeters = 100.0;

  // Getters
  RouteInformation? get route => _route;
  LatLng? get lastPosition => _lastPosition;
  double get completedPercentage => _completedPercentage;
  int get remainingDistanceMeters => _remainingDistanceMeters;
  int get remainingTimeSeconds => _remainingTimeSeconds;
  bool get isOnRoute => _isOnRoute;
  double get routeDeviationMeters => _routeDeviationMeters;
  RouteStep? get nextTurn => _nextTurn;
  int get distanceToNextTurnMeters => _distanceToNextTurnMeters;
  bool get isNavigating => _isNavigating;
  DateTime? get startTime => _startTime;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  // Configure the tracker's thresholds
  void configure({
    double? routeDeviationThresholdMeters,
    double? turnNotificationDistanceMeters,
  }) {
    if (routeDeviationThresholdMeters != null) {
      _routeDeviationThresholdMeters = routeDeviationThresholdMeters;
    }

    if (turnNotificationDistanceMeters != null) {
      _turnNotificationDistanceMeters = turnNotificationDistanceMeters;
    }
  }

  // Start tracking progress on a route
  void startTracking(RouteInformation route) {
    _route = route;
    _lastPosition = null;
    _lastStepIndex = 0;
    _completedPercentage = 0.0;
    _remainingDistanceMeters = route.distanceMeters;
    _remainingTimeSeconds = route.durationSeconds;
    _isOnRoute = true;
    _routeDeviationMeters = 0.0;
    _nextTurn = null;
    _distanceToNextTurnMeters = 0;
    _isNavigating = true;
    _startTime = DateTime.now();
    _lastUpdateTime = _startTime;

    // Find the first turn immediately
    _findNextTurn();
  }

  // Stop tracking
  void stopTracking() {
    _isNavigating = false;
    _route = null;
    _nextTurn = null;
  }

  // Update the tracker with a new user position
  bool updatePosition(LatLng position) {
    if (!_isNavigating || _route == null) return false;

    _lastPosition = position;
    _lastUpdateTime = DateTime.now();

    // Find the closest point on the route
    final closestRoutePoint = _findClosestRoutePoint(position);

    // Calculate route deviation
    _calculateRouteDeviation(position, closestRoutePoint);

    // Update progress metrics
    _updateProgressMetrics(position, closestRoutePoint);

    // Update turn predictions
    _updateTurnPrediction(position);

    return true;
  }

  // Find the closest point on the route to the current position
  LatLng _findClosestRoutePoint(LatLng position) {
    if (_route == null || _route!.polylinePoints.isEmpty) {
      return position;
    }

    // Use the navigation utilities to find the closest point
    return NavigationUtilities.findClosestPointOnRoute(
      position,
      _route!.polylinePoints,
    );
  }

  // Calculate how far the user has deviated from the route
  void _calculateRouteDeviation(LatLng position, LatLng closestRoutePoint) {
    // Calculate distance between current position and closest route point
    final distance = NavigationUtilities.calculateDistance(
      position,
      closestRoutePoint,
    );

    _routeDeviationMeters = distance;
    _isOnRoute = distance <= _routeDeviationThresholdMeters;
  }

  // Update progress metrics based on current position
  void _updateProgressMetrics(LatLng position, LatLng closestRoutePoint) {
    if (_route == null) return;

    // Find the index of the closest route point
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _route!.polylinePoints.length; i++) {
      final distance = NavigationUtilities.calculateDistance(
        closestRoutePoint,
        _route!.polylinePoints[i],
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Update the last route point index

    // Calculate remaining distance
    _remainingDistanceMeters = _calculateRemainingDistance(closestPointIndex);

    // Calculate completion percentage
    if (_route!.distanceMeters > 0) {
      _completedPercentage =
          1.0 - (_remainingDistanceMeters / _route!.distanceMeters);
      _completedPercentage = _completedPercentage.clamp(0.0, 1.0);
    }

    // Estimate remaining time
    if (_route!.durationSeconds > 0) {
      _remainingTimeSeconds =
          (_route!.durationSeconds * (1.0 - _completedPercentage)).round();
    }
  }

  // Calculate remaining distance from a point index
  int _calculateRemainingDistance(int fromIndex) {
    if (_route == null || _route!.polylinePoints.isEmpty) return 0;

    double distance = 0;

    // Add distance from current position to closest point if we have a last position
    if (_lastPosition != null) {
      final closestPoint = _route!.polylinePoints[fromIndex];
      distance += NavigationUtilities.calculateDistance(
        _lastPosition!,
        closestPoint,
      );
    }

    // Add distances for all remaining segments
    for (int i = fromIndex; i < _route!.polylinePoints.length - 1; i++) {
      distance += NavigationUtilities.calculateDistance(
        _route!.polylinePoints[i],
        _route!.polylinePoints[i + 1],
      );
    }

    return distance.round();
  }

  // Find the next turn on the route
  void _findNextTurn() {
    if (_route == null || !_route!.hasSteps) return;

    // Start looking from the current step index
    for (int i = _lastStepIndex; i < _route!.steps.length; i++) {
      final step = _route!.steps[i];

      // Check if this step is a turn
      if (step.isTurn) {
        _nextTurn = step;

        // Calculate distance to this turn
        if (_lastPosition != null) {
          _distanceToNextTurnMeters = NavigationUtilities.calculateDistance(
            _lastPosition!,
            step.startLocation,
          ).round();
        } else {
          // If we don't have a position yet, use the step's distance
          _distanceToNextTurnMeters = step.distanceMeters;
        }

        return;
      }
    }

    // No upcoming turn found
    _nextTurn = null;
    _distanceToNextTurnMeters = 0;
  }

  // Update turn prediction based on current position
  void _updateTurnPrediction(LatLng position) {
    if (_route == null || !_route!.hasSteps) return;

    // Find the current step based on position
    int currentStepIndex = _findCurrentStepIndex(position);

    // Update last step index if we've moved to a new step
    if (currentStepIndex > _lastStepIndex) {
      _lastStepIndex = currentStepIndex;

      // Check if we've passed the current next turn
      if (_nextTurn != null) {
        final passedStepIndex = _route!.steps.indexOf(_nextTurn!);
        if (currentStepIndex > passedStepIndex) {
          // We've passed the turn, find the next one
          _findNextTurn();
        }
      }
    }

    // If we don't have a next turn, try to find one
    if (_nextTurn == null) {
      _findNextTurn();
    } else {
      // Update distance to next turn
      _distanceToNextTurnMeters = NavigationUtilities.calculateDistance(
        position,
        _nextTurn!.startLocation,
      ).round();
    }
  }

  // Find the index of the current step based on position
  int _findCurrentStepIndex(LatLng position) {
    if (_route == null || !_route!.hasSteps) return 0;

    // Find which step contains the current position
    // Strategy: Find the closest step start/end point
    int closestStepIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _route!.steps.length; i++) {
      final step = _route!.steps[i];

      // Check distance to start location
      double distanceToStart = NavigationUtilities.calculateDistance(
        position,
        step.startLocation,
      );

      // Check distance to end location
      double distanceToEnd = NavigationUtilities.calculateDistance(
        position,
        step.endLocation,
      );

      double minStepDistance = math.min(distanceToStart, distanceToEnd);

      if (minStepDistance < minDistance) {
        minDistance = minStepDistance;
        closestStepIndex = i;
      }
    }

    return closestStepIndex;
  }

  // Calculate distance to the next turn
  int getDistanceToNextTurn() {
    if (_nextTurn == null || _lastPosition == null) return 0;

    return NavigationUtilities.calculateDistance(
      _lastPosition!,
      _nextTurn!.startLocation,
    ).round();
  }

  // Check if approaching a turn
  bool isApproachingTurn() {
    return _nextTurn != null &&
        _distanceToNextTurnMeters <= _turnNotificationDistanceMeters;
  }

  // Check if at a turn (very close to turn point)
  bool isAtTurn({double thresholdMeters = 20.0}) {
    return _nextTurn != null && _distanceToNextTurnMeters <= thresholdMeters;
  }

  // Reset the tracker
  void reset() {
    _route = null;
    _lastPosition = null;
    _lastStepIndex = 0;
    _completedPercentage = 0.0;
    _remainingDistanceMeters = 0;
    _remainingTimeSeconds = 0;
    _isOnRoute = true;
    _routeDeviationMeters = 0.0;
    _nextTurn = null;
    _distanceToNextTurnMeters = 0;
    _isNavigating = false;
    _startTime = null;
    _lastUpdateTime = null;
  }
}
