import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/hazard.dart';
import '../models/route_information.dart';
import '../services/vibration_service.dart';
import '../utils/navigation_utilities.dart';

class HazardService {
  // Singleton pattern
  static final HazardService _instance = HazardService._internal();
  factory HazardService() => _instance;
  HazardService._internal();

  final VibrationService _vibrationService = VibrationService();

  // Configuration
  static const double _defaultDetectionRadius = 100.0; // meters
  static const double _warningRadius = 50.0; // meters
  static const double _immediateWarningRadius = 20.0; // meters
  static const int _minTimeBetweenWarnings = 60; // seconds

  // State
  final List<Hazard> _knownHazards = [];
  final Set<String> _activeWarningHazards =
      {}; // IDs of hazards currently warning about
  DateTime? _lastWarningTime;
  bool _isMonitoring = false;

  // Stream controllers
  final _hazardDetectedController = StreamController<Hazard>.broadcast();
  final _hazardWarningController = StreamController<HazardWarning>.broadcast();
  final _hazardClearedController = StreamController<Hazard>.broadcast();

  // Public streams
  Stream<Hazard> get hazardDetectedStream => _hazardDetectedController.stream;
  Stream<HazardWarning> get hazardWarningStream =>
      _hazardWarningController.stream;
  Stream<Hazard> get hazardClearedStream => _hazardClearedController.stream;

  // Getters
  bool get isMonitoring => _isMonitoring;
  List<Hazard> get knownHazards => List.unmodifiable(_knownHazards);
  Set<String> get activeWarningHazards =>
      Set.unmodifiable(_activeWarningHazards);

  // Initialize hazard detection
  Future<void> initialize() async {
    // In a real app, we would load known hazards from a database or API
    await _vibrationService.initialize();

    // Add test hazards for development purposes
    _addTestHazards();
  }

  // Add test hazards for development
  void _addTestHazards() {
    // This would be replaced with real data in production
    _knownHazards.add(
      Hazard(
        id: '1',
        position: const LatLng(53.0783, 8.8017), // Example coordinates
        type: HazardType.construction,
        severity: HazardSeverity.medium,
        description: 'Sidewalk construction',
        reportedAt: DateTime.now().subtract(const Duration(days: 1)),
        validUntil: DateTime.now().add(const Duration(days: 14)),
        isVerified: true,
      ),
    );

    _knownHazards.add(
      Hazard(
        id: '2',
        position: const LatLng(53.0810, 8.8030), // Example coordinates
        type: HazardType.obstacle,
        severity: HazardSeverity.high,
        description: 'Large pothole on path',
        reportedAt: DateTime.now().subtract(const Duration(days: 2)),
        isVerified: true,
      ),
    );
  }

  // Start monitoring for hazards
  Future<bool> startMonitoring({RouteInformation? route}) async {
    if (_isMonitoring) return true;

    _isMonitoring = true;
    _lastWarningTime = null;
    _activeWarningHazards.clear();

    // Clean out expired hazards
    _removeExpiredHazards();

    return true;
  }

  // Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _activeWarningHazards.clear();
  }

  // Update with new position to detect hazards
  void updatePosition(LatLng position) {
    if (!_isMonitoring) return;

    // Check for nearby hazards
    _detectNearbyHazards(position);
  }

  // Detect if any known hazards are nearby
  void _detectNearbyHazards(LatLng position) {
    final nearbyHazards = <Hazard>[];
    final hazardsToWarnAbout = <Hazard>[];

    // First, collect all nearby hazards
    for (final hazard in _knownHazards) {
      // Skip expired hazards
      if (!hazard.isValid()) continue;

      final distance = NavigationUtilities.calculateDistance(
        position,
        hazard.position,
      );

      // Check if within detection radius (considering the hazard's own radius)
      if (distance <= _defaultDetectionRadius + hazard.radius) {
        nearbyHazards.add(hazard);

        // Check if we should warn about this hazard
        if (distance <= _warningRadius + hazard.radius) {
          hazardsToWarnAbout.add(hazard);
        }
      }
    }

    // Process hazards that need warnings
    for (final hazard in hazardsToWarnAbout) {
      // Only notify about hazards we haven't already warned about
      if (!_activeWarningHazards.contains(hazard.id)) {
        _activeWarningHazards.add(hazard.id);
        _hazardDetectedController.add(hazard);

        // Provide warning
        final distance = NavigationUtilities.calculateDistance(
          position,
          hazard.position,
        );
        _provideHazardWarning(hazard, distance);
      }
    }

    // Check if any hazards are no longer nearby (cleared)
    final currentHazardIds = nearbyHazards.map((h) => h.id).toSet();
    final clearedHazardIds = _activeWarningHazards.difference(currentHazardIds);

    for (final clearedId in clearedHazardIds) {
      final clearedHazard = _knownHazards.firstWhere(
        (h) => h.id == clearedId,
        orElse: () => _knownHazards.first, // Fallback, should never happen
      );

      _activeWarningHazards.remove(clearedId);
      _hazardClearedController.add(clearedHazard);
    }
  }

  // Provide appropriate warnings based on hazard severity and distance
  void _provideHazardWarning(Hazard hazard, double distance) {
    // Skip if we've warned recently (unless it's a critical hazard)
    if (_lastWarningTime != null &&
        hazard.severity != HazardSeverity.critical) {
      final timeSinceLastWarning = DateTime.now()
          .difference(_lastWarningTime!)
          .inSeconds;
      if (timeSinceLastWarning < _minTimeBetweenWarnings) return;
    }

    // Determine warning level based on distance and severity
    HazardWarningLevel warningLevel;

    if (distance <= _immediateWarningRadius) {
      warningLevel = HazardWarningLevel.immediate;
    } else {
      warningLevel = HazardWarningLevel.approaching;
    }

    // Escalate warning level for high severity hazards
    if (hazard.severity == HazardSeverity.critical) {
      warningLevel = HazardWarningLevel.immediate;
    } else if (hazard.severity == HazardSeverity.high &&
        warningLevel == HazardWarningLevel.approaching) {
      warningLevel = HazardWarningLevel.immediate;
    }

    final warning = HazardWarning(
      hazard: hazard,
      distance: distance,
      level: warningLevel,
      timestamp: DateTime.now(),
    );

    // Update last warning time
    _lastWarningTime = warning.timestamp;

    // Notify listeners
    _hazardWarningController.add(warning);

    // Provide haptic feedback
    _provideHapticWarning(warning);
  }

  // Provide appropriate haptic feedback based on warning level
  void _provideHapticWarning(HazardWarning warning) {
    // Adjust intensity based on severity and distance
    int intensity = VibrationService.mediumIntensity;

    switch (warning.hazard.severity) {
      case HazardSeverity.low:
        intensity = VibrationService.lowIntensity;
        break;
      case HazardSeverity.medium:
        intensity = VibrationService.mediumIntensity;
        break;
      case HazardSeverity.high:
      case HazardSeverity.critical:
        intensity = VibrationService.highIntensity;
        break;
    }

    // For immediate warnings, use higher intensity
    if (warning.level == HazardWarningLevel.immediate) {
      intensity = VibrationService.highIntensity;
    }

    _vibrationService.hazardWarningFeedback(intensity: intensity);
  }

  // Add a new hazard
  void addHazard(Hazard hazard) {
    // Check if hazard already exists
    final existingIndex = _knownHazards.indexWhere((h) => h.id == hazard.id);

    if (existingIndex >= 0) {
      _knownHazards[existingIndex] = hazard;
    } else {
      _knownHazards.add(hazard);
    }
  }

  // Remove a hazard
  void removeHazard(String hazardId) {
    _knownHazards.removeWhere((h) => h.id == hazardId);
    _activeWarningHazards.remove(hazardId);
  }

  // Remove expired hazards
  void _removeExpiredHazards() {
    final now = DateTime.now();
    _knownHazards.removeWhere(
      (hazard) => hazard.validUntil != null && hazard.validUntil!.isBefore(now),
    );
  }

  // Get hazards within a certain radius of a position
  List<Hazard> getHazardsNearby(LatLng position, double radiusMeters) {
    return _knownHazards.where((hazard) {
      if (!hazard.isValid()) return false;

      final distance = NavigationUtilities.calculateDistance(
        position,
        hazard.position,
      );
      return distance <= radiusMeters + hazard.radius;
    }).toList();
  }

  // Report a new hazard
  Hazard reportHazard({
    required LatLng position,
    required HazardType type,
    required HazardSeverity severity,
    required String description,
    double radius = 10.0,
    DateTime? validUntil,
    String? reportedBy,
  }) {
    final id = 'hazard_${DateTime.now().millisecondsSinceEpoch}';

    final hazard = Hazard(
      id: id,
      position: position,
      type: type,
      severity: severity,
      description: description,
      reportedAt: DateTime.now(),
      validUntil: validUntil,
      isVerified: false,
      radius: radius,
      reportedBy: reportedBy,
      verificationCount: 1,
    );

    addHazard(hazard);
    return hazard;
  }

  // Verify an existing hazard (e.g., when another user confirms it)
  Hazard verifyHazard(String hazardId) {
    final hazardIndex = _knownHazards.indexWhere((h) => h.id == hazardId);

    if (hazardIndex < 0) {
      throw Exception('Hazard not found: $hazardId');
    }

    final hazard = _knownHazards[hazardIndex];
    final updatedHazard = hazard.copyWith(
      isVerified: true,
      verificationCount: (hazard.verificationCount ?? 0) + 1,
    );

    _knownHazards[hazardIndex] = updatedHazard;
    return updatedHazard;
  }

  // Clear all known hazards
  void clearHazards() {
    _knownHazards.clear();
    _activeWarningHazards.clear();
  }

  // Dispose resources
  void dispose() {
    stopMonitoring();
    _hazardDetectedController.close();
    _hazardWarningController.close();
    _hazardClearedController.close();
  }
}

// Warning level for hazards
enum HazardWarningLevel {
  approaching, // Hazard is nearby
  immediate, // Hazard is very close
}

// Hazard warning details
class HazardWarning {
  final Hazard hazard;
  final double distance;
  final HazardWarningLevel level;
  final DateTime timestamp;

  HazardWarning({
    required this.hazard,
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

  String get warningMessage {
    String message = hazard.getFullDescription();

    if (level == HazardWarningLevel.immediate) {
      message = 'CAUTION! $message ahead';
    } else {
      message = '$message approaching';
    }

    return '$message ($distanceText)';
  }
}
