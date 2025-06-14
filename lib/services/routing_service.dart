import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RouteInformation;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:dio/dio.dart';
import '../models/waypoint.dart';
import '../models/route_information.dart';
import '../utils/env.dart'; // Import env utility instead of secrets

enum TravelMode { walking, cycling, driving, transit }

class RoutingService {
  // Singleton pattern
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  // Google Directions API endpoint
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  // Get API key from environment variables
  static String get _apiKey => Env.googleMapsApiKey;

  // HTTP client
  final Dio _dio = Dio();

  // Calculate route between two points
  Future<RouteInformation?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng> waypoints = const [],
    TravelMode mode = TravelMode.walking,
  }) async {
    try {
      // Build waypoints string if any waypoints are provided
      String waypointsString = '';
      if (waypoints.isNotEmpty) {
        waypointsString =
            'waypoints=optimize:true|${waypoints.map((point) => '${point.latitude},${point.longitude}').join('|')}';
      }

      // Convert travel mode to string
      String travelMode;
      switch (mode) {
        case TravelMode.walking:
          travelMode = 'walking';
          break;
        case TravelMode.cycling:
          travelMode = 'bicycling';
          break;
        case TravelMode.driving:
          travelMode = 'driving';
          break;
        case TravelMode.transit:
          travelMode = 'transit';
          break;
      }

      // Build the request URL
      final url =
          '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '${waypointsString.isNotEmpty ? '&$waypointsString' : ''}'
          '&mode=$travelMode'
          '&key=$_apiKey';

      // Make the API request
      final response = await _dio.get(url);

      // Check if the request was successful
      if (response.data['status'] == 'OK') {
        // Parse the route data
        return _parseRouteFromResponse(response.data);
      } else {
        // Handle API error
        debugPrint('Error calculating route: ${response.data['status']}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception calculating route: $e');
      return null;
    }
  }

  // Parse route information from API response
  RouteInformation _parseRouteFromResponse(Map<String, dynamic> response) {
    // Get the first route from the response (we can extend this to handle alternatives)
    final route = response['routes'][0];

    // Get the route's encoded polyline
    final encodedPolyline = route['overview_polyline']['points'];

    // Decode the polyline to get the list of points
    final polylinePoints = PolylinePoints()
        .decodePolyline(encodedPolyline)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    // Get the route's legs (segments between waypoints)
    final legs = route['legs'];

    // Extract distance and duration
    int totalDistanceMeters = 0;
    int totalDurationSeconds = 0;

    // Extract steps (turn-by-turn instructions)
    final List<RouteStep> steps = [];

    for (var leg in legs) {
      totalDistanceMeters += (leg['distance']['value'] as num).toInt();
      totalDurationSeconds += (leg['duration']['value'] as num).toInt();

      // Extract steps from this leg
      for (var step in leg['steps']) {
        final instruction = step['html_instructions'];
        final maneuver = step['maneuver'] ?? '';
        final distance = step['distance']['value'];
        final duration = step['duration']['value'];
        final startLocation = LatLng(
          step['start_location']['lat'],
          step['start_location']['lng'],
        );
        final endLocation = LatLng(
          step['end_location']['lat'],
          step['end_location']['lng'],
        );

        steps.add(
          RouteStep(
            instruction: instruction,
            maneuver: maneuver,
            distanceMeters: distance,
            durationSeconds: duration,
            startLocation: startLocation,
            endLocation: endLocation,
          ),
        );
      }
    }

    // Create waypoints from route data
    final List<Waypoint> routeWaypoints = [];

    // Add origin waypoint
    routeWaypoints.add(
      Waypoint(
        position: LatLng(
          legs[0]['start_location']['lat'],
          legs[0]['start_location']['lng'],
        ),
        name: legs[0]['start_address'],
        type: WaypointType.origin,
      ),
    );

    // Add intermediate waypoints if there are multiple legs
    for (int i = 0; i < legs.length - 1; i++) {
      routeWaypoints.add(
        Waypoint(
          position: LatLng(
            legs[i]['end_location']['lat'],
            legs[i]['end_location']['lng'],
          ),
          name: legs[i]['end_address'],
          type: WaypointType.intermediate,
        ),
      );
    }

    // Add destination waypoint
    routeWaypoints.add(
      Waypoint(
        position: LatLng(
          legs.last['end_location']['lat'],
          legs.last['end_location']['lng'],
        ),
        name: legs.last['end_address'],
        type: WaypointType.destination,
      ),
    );

    // Create and return the route information
    return RouteInformation(
      polylinePoints: polylinePoints,
      distanceMeters: totalDistanceMeters,
      durationSeconds: totalDurationSeconds,
      steps: steps,
      waypoints: routeWaypoints,
    );
  }

  // Generate a simple route line between two points
  List<LatLng> _generateSimpleRoute(LatLng start, LatLng end) {
    const int numPoints = 10; // Number of points to generate along the route

    final points = <LatLng>[];
    points.add(start);

    // Generate intermediate points
    for (int i = 1; i < numPoints; i++) {
      final ratio = i / numPoints;

      // Simple linear interpolation
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;

      // Add some randomness for a more realistic route
      final random = Random();
      final jitter = 0.0002 * (random.nextDouble() - 0.5);

      points.add(LatLng(lat + jitter, lng + jitter));
    }

    points.add(end);
    return points;
  }

  // Generate simple steps for the route
  List<RouteStep> _generateSimpleSteps(List<LatLng> points) {
    if (points.length < 3) {
      // For very short routes, just one step
      return [
        RouteStep(
          instruction: 'Go to destination',
          maneuver: 'straight',
          distanceMeters: _calculateDistance(points.first, points.last).round(),
          durationSeconds: 60,
          startLocation: points.first,
          endLocation: points.last,
        ),
      ];
    }

    final steps = <RouteStep>[];
    final stepPoints = [
      0,
      points.length ~/ 3,
      (points.length * 2) ~/ 3,
      points.length - 1,
    ];

    // First segment
    steps.add(
      RouteStep(
        instruction: 'Head towards destination',
        maneuver: 'straight',
        distanceMeters: _calculateSegmentDistance(
          points,
          stepPoints[0],
          stepPoints[1],
        ).round(),
        durationSeconds: 60,
        startLocation: points[stepPoints[0]],
        endLocation: points[stepPoints[1]],
      ),
    );

    // Middle segment with a turn
    final turnDirection = Random().nextBool() ? 'left' : 'right';
    steps.add(
      RouteStep(
        instruction: 'Turn $turnDirection',
        maneuver: turnDirection,
        distanceMeters: _calculateSegmentDistance(
          points,
          stepPoints[1],
          stepPoints[2],
        ).round(),
        durationSeconds: 90,
        startLocation: points[stepPoints[1]],
        endLocation: points[stepPoints[2]],
      ),
    );

    // Final segment
    steps.add(
      RouteStep(
        instruction: 'Continue to destination',
        maneuver: 'straight',
        distanceMeters: _calculateSegmentDistance(
          points,
          stepPoints[2],
          stepPoints[3],
        ).round(),
        durationSeconds: 120,
        startLocation: points[stepPoints[2]],
        endLocation: points[stepPoints[3]],
      ),
    );

    return steps;
  }

  // Calculate total route distance
  double _calculateRouteDistance(List<LatLng> points) {
    double distance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      distance += _calculateDistance(points[i], points[i + 1]);
    }
    return distance;
  }

  // Calculate segment distance
  double _calculateSegmentDistance(List<LatLng> points, int start, int end) {
    double distance = 0;
    for (int i = start; i < end; i++) {
      distance += _calculateDistance(points[i], points[i + 1]);
    }
    return distance;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // in meters

    final lat1 = p1.latitude * (pi / 180);
    final lat2 = p2.latitude * (pi / 180);
    final dLat = (p2.latitude - p1.latitude) * (pi / 180);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Calculate route duration based on distance and travel mode
  int _calculateRouteDuration(double distanceMeters, TravelMode mode) {
    // Average speeds in meters per second
    double speed;
    switch (mode) {
      case TravelMode.walking:
        speed = 1.4; // ~5 km/h
        break;
      case TravelMode.cycling:
        speed = 4.2; // ~15 km/h
        break;
      case TravelMode.driving:
        speed = 11.1; // ~40 km/h in urban areas
        break;
      case TravelMode.transit:
        speed = 8.3; // ~30 km/h
        break;
    }

    return (distanceMeters / speed).round();
  }
}
