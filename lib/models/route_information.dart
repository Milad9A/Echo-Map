import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'waypoint.dart';

class RouteInformation extends Equatable {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final List<RouteStep> steps;
  final List<Waypoint> waypoints;
  final DateTime createdAt;

  RouteInformation({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.waypoints,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Get distance in kilometers, formatted
  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  // Get duration in minutes or hours, formatted
  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes / 60;
      final remainingMinutes = minutes % 60;
      return '${hours.floor()} hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  // Get the origin waypoint
  Waypoint get origin => waypoints.first;

  // Get the destination waypoint
  Waypoint get destination => waypoints.last;

  // Get intermediate waypoints
  List<Waypoint> get intermediateWaypoints =>
      waypoints.length > 2 ? waypoints.sublist(1, waypoints.length - 1) : [];

  // Check if route has steps
  bool get hasSteps => steps.isNotEmpty;

  // Get the next step after a specific position
  RouteStep? getNextStepAfter(LatLng position) {
    // Find the closest step start point to the current position
    int closestStepIndex = -1;
    double closestDistance = double.infinity;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final distance = _calculateDistance(position, step.startLocation);

      if (distance < closestDistance) {
        closestDistance = distance;
        closestStepIndex = i;
      }
    }

    // If we found a closest step and it's not the last one,
    // return the next step as the upcoming step
    if (closestStepIndex >= 0 && closestStepIndex < steps.length - 1) {
      return steps[closestStepIndex + 1];
    }

    return null;
  }

  // Calculate distance between two points (simplified version)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters

    final lat1 = point1.latitude * (3.141592653589793 / 180);
    final lat2 = point2.latitude * (3.141592653589793 / 180);
    final dLat =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final dLon =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final a =
        pow(sin(dLat / 2), 2) + pow(sin(dLon / 2), 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  List<Object?> get props => [
    polylinePoints,
    distanceMeters,
    durationSeconds,
    steps,
    waypoints,
    createdAt,
  ];
}

class RouteStep extends Equatable {
  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;

  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
  });

  // Get distance in readable format
  String get distanceText {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  // Get duration in readable format
  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 1) {
      return '$durationSeconds sec';
    } else {
      return '$minutes min';
    }
  }

  // Get turn direction based on maneuver
  String get turnDirection {
    if (maneuver.contains('left')) {
      return 'left';
    } else if (maneuver.contains('right')) {
      return 'right';
    } else if (maneuver.contains('u-turn')) {
      return 'uturn';
    } else {
      return 'straight';
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
  ];
}
