import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/navigation_utilities.dart';
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
      final distance = NavigationUtilities.calculateDistance(
        position,
        step.startLocation,
      );

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

  // Find the next turn after a specific position
  RouteStep? getNextTurnAfter(LatLng position) {
    // Find the closest step first
    final nextStep = getNextStepAfter(position);
    if (nextStep == null) return null;

    // Check if this step is a turn
    if (nextStep.isTurn) {
      return nextStep;
    }

    // If not, look ahead for the next turn
    final nextStepIndex = steps.indexOf(nextStep);
    if (nextStepIndex < 0) return null;

    // Look ahead for a step with a turn maneuver
    for (int i = nextStepIndex + 1; i < steps.length; i++) {
      if (steps[i].isTurn) {
        return steps[i];
      }
    }

    return null;
  }

  // Get the remaining distance from a position to the destination
  int getRemainingDistance(LatLng position) {
    // Find the closest point on the route to the current position
    final closestPoint = NavigationUtilities.findClosestPointOnRoute(
      position,
      polylinePoints,
    );

    // Find the index of the closest point
    int closestPointIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < polylinePoints.length; i++) {
      final distance = NavigationUtilities.calculateDistance(
        closestPoint,
        polylinePoints[i],
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Calculate remaining distance by summing distances between remaining points
    if (closestPointIndex >= 0 &&
        closestPointIndex < polylinePoints.length - 1) {
      double remainingDistance = 0;

      // Add distance from current position to closest route point
      remainingDistance += NavigationUtilities.calculateDistance(
        position,
        closestPoint,
      );

      // Add distances between remaining route points
      for (int i = closestPointIndex; i < polylinePoints.length - 1; i++) {
        remainingDistance += NavigationUtilities.calculateDistance(
          polylinePoints[i],
          polylinePoints[i + 1],
        );
      }

      return remainingDistance.round();
    }

    // Fallback: return the total route distance
    return distanceMeters;
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

  // Check if this step is a turn
  bool get isTurn {
    return maneuver.contains('left') ||
        maneuver.contains('right') ||
        maneuver.contains('u-turn');
  }

  // Calculate bearing of this step
  double get bearing {
    return NavigationUtilities.calculateBearing(startLocation, endLocation);
  }

  // Get bearing direction name
  String get bearingDirectionName {
    return NavigationUtilities.getDirectionFromBearing(bearing);
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
