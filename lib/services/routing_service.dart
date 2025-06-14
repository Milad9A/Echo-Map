import 'dart:async';
import 'package:flutter/material.dart' hide RouteInformation;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:dio/dio.dart';
import '../models/waypoint.dart';
import '../models/route_information.dart';
import '../utils/env.dart'; // Import env utility instead of secrets

enum TravelMode { walking, bicycling, driving, transit }

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
        case TravelMode.bicycling:
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
}
