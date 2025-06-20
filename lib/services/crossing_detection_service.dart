import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/street_crossing.dart';
import '../models/route_information.dart';
import '../services/vibration_service.dart';
import '../utils/navigation_utilities.dart';

class CrossingDetectionService {
  // Singleton pattern
  static final CrossingDetectionService _instance =
      CrossingDetectionService._internal();
  factory CrossingDetectionService() => _instance;
  CrossingDetectionService._internal();

  final VibrationService _vibrationService = VibrationService();

  // Configuration
  static const double _defaultDetectionRadius = 50.0; // meters
  static const double _firstWarningDistance = 30.0; // meters
  static const double _finalWarningDistance = 10.0; // meters
  static const int _minTimeBetweenWarnings = 30; // seconds

  // State
  final List<StreetCrossing> _knownCrossings = [];
  StreetCrossing? _approachingCrossing;
  DateTime? _lastWarningTime;
  bool _isMonitoring = false;

  // Stream controllers
  final _crossingApproachController =
      StreamController<StreetCrossing>.broadcast();
  final _crossingWarningController =
      StreamController<CrossingWarning>.broadcast();

  // Public streams
  Stream<StreetCrossing> get crossingApproachStream =>
      _crossingApproachController.stream;
  Stream<CrossingWarning> get crossingWarningStream =>
      _crossingWarningController.stream;

  // Getters
  bool get isMonitoring => _isMonitoring;
  StreetCrossing? get approachingCrossing => _approachingCrossing;
  List<StreetCrossing> get knownCrossings => List.unmodifiable(_knownCrossings);

  // Start monitoring for crossings along a route
  Future<bool> startMonitoring({RouteInformation? route}) async {
    if (_isMonitoring) return true;

    _isMonitoring = true;
    _lastWarningTime = null;

    // If a route is provided, we could extract potential crossings from it
    if (route != null) {
      _extractCrossingsFromRoute(route);
    }

    return true;
  }

  // Extract potential crossings from a navigation route
  void _extractCrossingsFromRoute(RouteInformation route) {
    // In a real implementation, this would analyze the route and identify
    // likely crossing points based on road intersections
    // For now, we'll just use our predefined crossings
  }

  // Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _approachingCrossing = null;
  }

  // Update with new position to detect crossings
  void updatePosition(LatLng position) {
    if (!_isMonitoring) return;

    // Check for nearby crossings
    _detectNearbyCrossings(position);
  }

  // Detect if any known crossings are nearby
  void _detectNearbyCrossings(LatLng position) {
    StreetCrossing? nearestCrossing;
    double minDistance = double.infinity;

    for (final crossing in _knownCrossings) {
      final distance = NavigationUtilities.calculateDistance(
        position,
        crossing.position,
      );

      if (distance < minDistance && distance <= _defaultDetectionRadius) {
        minDistance = distance;
        nearestCrossing = crossing;
      }
    }

    // Check if we're approaching a new crossing
    if (nearestCrossing != null &&
        (_approachingCrossing == null ||
            _approachingCrossing!.id != nearestCrossing.id)) {
      _approachingCrossing = nearestCrossing;
      _crossingApproachController.add(nearestCrossing);

      // Give initial warning
      _provideWarning(nearestCrossing, minDistance);
    }
    // Check if we're getting closer to the current crossing
    else if (_approachingCrossing != null && nearestCrossing != null) {
      _checkWarningThresholds(_approachingCrossing!, minDistance);
    }
    // Check if we've moved away from the crossing
    else if (_approachingCrossing != null &&
        (nearestCrossing == null || minDistance > _defaultDetectionRadius)) {
      _approachingCrossing = null;
    }
  }

  // Check if we need to provide updated warnings based on distance
  void _checkWarningThresholds(StreetCrossing crossing, double distance) {
    // Skip if we've warned recently
    if (_lastWarningTime != null) {
      final timeSinceLastWarning =
          DateTime.now().difference(_lastWarningTime!).inSeconds;
      if (timeSinceLastWarning < _minTimeBetweenWarnings) return;
    }

    // Provide appropriate warnings based on distance
    _provideWarning(crossing, distance);
  }

  // Provide a warning with appropriate intensity based on distance
  void _provideWarning(StreetCrossing crossing, double distance) {
    CrossingWarningLevel warningLevel;

    if (distance <= _finalWarningDistance) {
      warningLevel = CrossingWarningLevel.immediate;
    } else if (distance <= _firstWarningDistance) {
      warningLevel = CrossingWarningLevel.approaching;
    } else {
      warningLevel = CrossingWarningLevel.distant;
    }

    final warning = CrossingWarning(
      crossing: crossing,
      distance: distance,
      level: warningLevel,
      timestamp: DateTime.now(),
    );

    // Update last warning time
    _lastWarningTime = warning.timestamp;

    // Notify listeners
    _crossingWarningController.add(warning);

    // Provide haptic feedback
    _provideHapticWarning(warning);
  }

  // Provide appropriate haptic feedback based on warning level
  void _provideHapticWarning(CrossingWarning warning) {
    switch (warning.level) {
      case CrossingWarningLevel.distant:
        _vibrationService.crossingStreetFeedback(
          intensity: VibrationService.lowIntensity,
        );
        break;
      case CrossingWarningLevel.approaching:
        _vibrationService.crossingStreetFeedback(
          intensity: VibrationService.mediumIntensity,
        );
        break;
      case CrossingWarningLevel.immediate:
        _vibrationService.crossingStreetFeedback(
          intensity: VibrationService.highIntensity,
        );
        break;
    }
  }

  // Add a new crossing to the known list
  void addCrossing(StreetCrossing crossing) {
    // Check if crossing already exists
    final existingIndex = _knownCrossings.indexWhere(
      (c) => c.id == crossing.id,
    );

    if (existingIndex >= 0) {
      _knownCrossings[existingIndex] = crossing;
    } else {
      _knownCrossings.add(crossing);
    }
  }

  // Remove a crossing
  void removeCrossing(String crossingId) {
    _knownCrossings.removeWhere((c) => c.id == crossingId);
  }

  // Get crossings within a certain radius of a position
  List<StreetCrossing> getCrossingsNearby(
    LatLng position,
    double radiusMeters,
  ) {
    return _knownCrossings.where((crossing) {
      final distance = NavigationUtilities.calculateDistance(
        position,
        crossing.position,
      );
      return distance <= radiusMeters;
    }).toList();
  }

  // Clear all known crossings
  void clearCrossings() {
    _knownCrossings.clear();
    _approachingCrossing = null;
  }

  // Dispose resources
  void dispose() {
    stopMonitoring();
    _crossingApproachController.close();
    _crossingWarningController.close();
  }
}

// Warning level for crossings
enum CrossingWarningLevel {
  distant, // First detection, far away
  approaching, // Getting closer
  immediate, // Very close, about to cross
}

// Crossing warning details
class CrossingWarning {
  final StreetCrossing crossing;
  final double distance;
  final CrossingWarningLevel level;
  final DateTime timestamp;

  CrossingWarning({
    required this.crossing,
    required this.distance,
    required this.level,
    required this.timestamp,
  });

  String get distanceText {
    if (distance < 100) {
      return '${distance.round()} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }
}
