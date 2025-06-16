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
  double _routeDeviationThresholdMeters = 10.0; // Reduced from 20.0
  double _turnNotificationDistanceMeters = 30.0; // Reduced from 100.0

  // Position tracking with smoothing
  final List<LatLng> _recentPositions = [];
  double _currentSpeed = 0.0;

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

  // Enhanced position update with smoothing
  bool updatePosition(LatLng position) {
    if (!_isNavigating || _route == null) return false;

    final now = DateTime.now();

    // Add position to recent positions for smoothing
    _recentPositions.add(position);
    if (_recentPositions.length > 5) {
      _recentPositions.removeAt(0);
    }

    // Calculate smoothed position
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

    // Calculate speed if we have previous position
    if (_lastPosition != null && _lastUpdateTime != null) {
      final distance =
          NavigationUtilities.calculateDistance(_lastPosition!, position);
      final timeDiff = now.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
      if (timeDiff > 0) {
        _currentSpeed = distance / timeDiff;
      }
    }

    _lastPosition = position;
    _lastUpdateTime = now;

    // Find the closest point on the route using smoothed position
    final closestRoutePoint = _findClosestRoutePointPrecise(smoothedPosition);

    // Calculate route deviation using smoothed position
    _calculateRouteDeviationPrecise(smoothedPosition, closestRoutePoint);

    // Update progress metrics
    _updateProgressMetrics(smoothedPosition, closestRoutePoint);

    // Update turn predictions with speed consideration
    _updateTurnPredictionPrecise(smoothedPosition);

    return true;
  }

  // Enhanced closest point finding with segment projection
  LatLng _findClosestRoutePointPrecise(LatLng position) {
    if (_route == null || _route!.polylinePoints.isEmpty) {
      return position;
    }

    if (_route!.polylinePoints.length == 1) {
      return _route!.polylinePoints.first;
    }

    double minDistance = double.infinity;
    LatLng closestPoint = _route!.polylinePoints.first;

    // Check each segment of the polyline
    for (int i = 0; i < _route!.polylinePoints.length - 1; i++) {
      final LatLng segmentStart = _route!.polylinePoints[i];
      final LatLng segmentEnd = _route!.polylinePoints[i + 1];

      final LatLng projectedPoint = _projectPointOnSegment(
        position,
        segmentStart,
        segmentEnd,
      );

      final double distance =
          NavigationUtilities.calculateDistance(position, projectedPoint);

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projectedPoint;
      }
    }

    return closestPoint;
  }

  // Project point onto segment with better precision
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
      return segmentStart;
    }

    final double t = ((x - x1) * dx + (y - y1) * dy) / segmentLengthSquared;
    final double clampedT = t.clamp(0.0, 1.0);

    return LatLng(
      y1 + clampedT * dy,
      x1 + clampedT * dx,
    );
  }

  // Enhanced deviation calculation with smoothing
  void _calculateRouteDeviationPrecise(
      LatLng position, LatLng closestRoutePoint) {
    final distance =
        NavigationUtilities.calculateDistance(position, closestRoutePoint);

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

  // Enhanced turn prediction with speed and distance considerations
  void _updateTurnPredictionPrecise(LatLng position) {
    if (_route == null || !_route!.hasSteps) return;

    if (_currentSpeed > 1.5) {
      // Moving faster than normal walking
    } else if (_currentSpeed < 0.5) {
      // Moving very slowly
    }

    // Find the current step based on position with better accuracy
    int currentStepIndex = _findCurrentStepIndexPrecise(position);

    // Update last step index if we've moved to a new step
    if (currentStepIndex > _lastStepIndex) {
      _lastStepIndex = currentStepIndex;

      // Check if we've passed the current next turn
      if (_nextTurn != null) {
        final passedStepIndex = _route!.steps.indexOf(_nextTurn!);
        if (currentStepIndex > passedStepIndex) {
          _findNextTurn();
        }
      }
    }

    // Find next turn with dynamic distance
    if (_nextTurn == null) {
      _findNextTurn();
    } else {
      _distanceToNextTurnMeters = NavigationUtilities.calculateDistance(
        position,
        _nextTurn!.startLocation,
      ).round();
    }
  }

  // More precise step index finding
  int _findCurrentStepIndexPrecise(LatLng position) {
    if (_route == null || !_route!.hasSteps) return 0;

    int closestStepIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _route!.steps.length; i++) {
      final step = _route!.steps[i];

      // Check distance to step start and end locations
      double distanceToStart =
          NavigationUtilities.calculateDistance(position, step.startLocation);
      double distanceToEnd =
          NavigationUtilities.calculateDistance(position, step.endLocation);

      // Also check if we're between start and end (on the step path)
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

  // Check if approaching a turn with enhanced precision
  bool isApproachingTurn() {
    if (_nextTurn == null) return false;

    // Adjust threshold based on speed
    double threshold = _turnNotificationDistanceMeters;
    if (_currentSpeed > 1.5) {
      threshold = 50.0;
    } else if (_currentSpeed < 0.5) {
      threshold = 20.0;
    }

    return _distanceToNextTurnMeters <= threshold;
  }

  // Check if at turn with speed consideration
  bool isAtTurn({double? thresholdMeters}) {
    if (_nextTurn == null) return false;

    double threshold = thresholdMeters ?? 10.0;

    // Adjust threshold based on speed
    if (_currentSpeed > 1.5) {
      threshold = 15.0;
    } else if (_currentSpeed < 0.5) {
      threshold = 8.0;
    }

    return _distanceToNextTurnMeters <= threshold;
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
    _recentPositions.clear();
    _currentSpeed = 0.0;
  }
}
