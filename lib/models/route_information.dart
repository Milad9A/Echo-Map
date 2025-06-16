import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'waypoint.dart';
import 'dart:math';

enum RouteStepType {
  start,
  turn,
  straight,
  arrival,
  ferry,
  roundabout,
}

class RouteStep extends Equatable {
  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final RouteStepType type;
  final String? streetName;

  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    this.type = RouteStepType.straight,
    this.streetName,
  });

  // Get turn direction from maneuver
  String get turnDirection {
    if (maneuver.contains('left')) return 'left';
    if (maneuver.contains('right')) return 'right';
    if (maneuver.contains('uturn') || maneuver.contains('u-turn')) {
      return 'uturn';
    }
    return 'straight';
  }

  // Check if this step represents a turn
  bool get isTurn {
    return turnDirection != 'straight' && type == RouteStepType.turn;
  }

  // Get human-readable distance
  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  // Get human-readable duration
  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  @override
  List<Object?> get props => [
        instruction,
        maneuver,
        distanceMeters,
        durationSeconds,
        startLocation,
        endLocation,
        type,
        streetName,
      ];
}

class RouteInformation extends Equatable {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteStep> steps;
  final List<Waypoint> waypoints;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  RouteInformation({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.waypoints,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  // Get origin waypoint
  Waypoint get origin {
    return waypoints.firstWhere(
      (w) => w.type == WaypointType.origin,
      orElse: () => waypoints.first,
    );
  }

  // Get destination waypoint
  Waypoint get destination {
    return waypoints.firstWhere(
      (w) => w.type == WaypointType.destination,
      orElse: () => waypoints.last,
    );
  }

  // Check if route has steps
  bool get hasSteps => steps.isNotEmpty;

  // Get human-readable distance
  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  // Get human-readable duration
  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  // Calculate remaining distance from a given position
  int getRemainingDistance(LatLng currentPosition) {
    if (polylinePoints.isEmpty) return distanceMeters;

    // Find the closest point on the route
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < polylinePoints.length; i++) {
      final distance = _calculateDistance(currentPosition, polylinePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Calculate remaining distance from closest point to destination
    double remainingDistance = 0;
    for (int i = closestIndex; i < polylinePoints.length - 1; i++) {
      remainingDistance +=
          _calculateDistance(polylinePoints[i], polylinePoints[i + 1]);
    }

    return remainingDistance.round();
  }

  // Calculate estimated remaining time from a given position
  int getRemainingTime(LatLng currentPosition) {
    final remainingDistance = getRemainingDistance(currentPosition);
    if (distanceMeters == 0) return 0;

    // Proportional calculation based on original time estimate
    final ratio = remainingDistance / distanceMeters;
    return (durationSeconds * ratio).round();
  }

  // Get the next step from current position
  RouteStep? getNextStep(LatLng currentPosition) {
    if (steps.isEmpty) return null;

    // Find the step that contains or is closest to the current position
    for (final step in steps) {
      final distanceToStepStart =
          _calculateDistance(currentPosition, step.startLocation);
      if (distanceToStepStart <= 100) {
        // Within 100 meters
        return step;
      }
    }

    return steps.first; // Return first step if none found
  }

  // Check if position is on the route (within tolerance)
  bool isOnRoute(LatLng position, {double toleranceMeters = 50.0}) {
    if (polylinePoints.isEmpty) return false;

    for (final point in polylinePoints) {
      final distance = _calculateDistance(position, point);
      if (distance <= toleranceMeters) {
        return true;
      }
    }

    return false;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Create a copy with some fields changed
  RouteInformation copyWith({
    List<LatLng>? polylinePoints,
    int? distanceMeters,
    int? durationSeconds,
    List<RouteStep>? steps,
    List<Waypoint>? waypoints,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return RouteInformation(
      polylinePoints: polylinePoints ?? this.polylinePoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      steps: steps ?? this.steps,
      waypoints: waypoints ?? this.waypoints,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        polylinePoints,
        distanceMeters,
        durationSeconds,
        steps,
        waypoints,
        createdAt,
        metadata,
      ];
}
