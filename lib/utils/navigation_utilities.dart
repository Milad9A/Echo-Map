import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for navigation-related calculations
class NavigationUtilities {
  /// Calculate distance between two coordinates in meters using the Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // in meters

    // Convert latitude and longitude from degrees to radians
    final lat1 = point1.latitude * (pi / 180);
    final lon1 = point1.longitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final lon2 = point2.longitude * (pi / 180);

    // Haversine formula
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate bearing in degrees from one point to another
  /// Returns angle in degrees (0-360) where 0 is North, 90 is East, etc.
  static double calculateBearing(LatLng start, LatLng end) {
    // Convert to radians
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    // Calculate the bearing
    final y = sin(endLng - startLng) * cos(endLat);
    final x =
        cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(endLng - startLng);
    final bearingRad = atan2(y, x);

    // Convert to degrees
    var bearingDeg = (bearingRad * (180 / pi) + 360) % 360;

    return bearingDeg;
  }

  /// Find the closest point on a polyline to a given point
  static LatLng findClosestPointOnRoute(
    LatLng point,
    List<LatLng> routePoints,
  ) {
    if (routePoints.isEmpty) return point;
    if (routePoints.length == 1) return routePoints.first;

    double minDistance = double.infinity;
    LatLng closestPoint = routePoints.first;

    // Check each segment of the polyline
    for (int i = 0; i < routePoints.length - 1; i++) {
      final LatLng segmentStart = routePoints[i];
      final LatLng segmentEnd = routePoints[i + 1];

      final LatLng projectedPoint = projectPointOnSegment(
        point,
        segmentStart,
        segmentEnd,
      );

      final double distance = calculateDistance(point, projectedPoint);

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projectedPoint;
      }
    }

    return closestPoint;
  }

  /// Project a point onto a line segment defined by two points
  static LatLng projectPointOnSegment(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    // Convert all points to cartesian coordinates for simpler calculation
    // This is an approximation that works for small distances
    final double x = point.longitude;
    final double y = point.latitude;
    final double x1 = segmentStart.longitude;
    final double y1 = segmentStart.latitude;
    final double x2 = segmentEnd.longitude;
    final double y2 = segmentEnd.latitude;

    // Calculate the projection
    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double segmentLengthSquared = dx * dx + dy * dy;

    // If segment is a point, return the segment start
    if (segmentLengthSquared == 0) {
      return segmentStart;
    }

    // Calculate the projection factor
    final double t = max(
      0,
      min(1, ((x - x1) * dx + (y - y1) * dy) / segmentLengthSquared),
    );

    // Calculate the projected point
    final double projectedX = x1 + t * dx;
    final double projectedY = y1 + t * dy;

    return LatLng(projectedY, projectedX);
  }

  /// Calculate if a user has deviated from a route
  /// Returns the deviation distance in meters, or 0 if on route
  static double calculateRouteDeviation(
    LatLng currentPosition,
    List<LatLng> routePoints,
    double thresholdMeters,
  ) {
    if (routePoints.isEmpty) return 0;

    // Find the closest point on the route to the current position
    final LatLng closestPoint = findClosestPointOnRoute(
      currentPosition,
      routePoints,
    );

    // Calculate the distance to the closest point
    final double distance = calculateDistance(currentPosition, closestPoint);

    // Return the deviation distance if it exceeds the threshold
    return distance > thresholdMeters ? distance : 0;
  }

  /// Get a direction name from a bearing angle
  static String getDirectionFromBearing(double bearing) {
    const directions = [
      'North',
      'Northeast',
      'East',
      'Southeast',
      'South',
      'Southwest',
      'West',
      'Northwest',
      'North',
    ];

    // Convert bearing to 0-8 index for the directions array
    final index = ((bearing + 22.5) % 360) ~/ 45;

    return directions[index];
  }

  /// Get a turn direction based on change in bearing
  static String getTurnDirection(double currentBearing, double targetBearing) {
    // Normalize the difference between current and target bearing
    double diff = (targetBearing - currentBearing) % 360;
    if (diff < 0) diff += 360;

    // Determine turn direction based on the bearing difference
    if (diff < 20 || diff > 340) {
      return "straight";
    } else if (diff >= 20 && diff < 160) {
      return diff < 100 ? "right" : "sharp_right";
    } else if (diff >= 160 && diff < 200) {
      return "uturn";
    } else if (diff >= 200 && diff <= 340) {
      return diff > 260 ? "left" : "sharp_left";
    }

    return "unknown";
  }
}
