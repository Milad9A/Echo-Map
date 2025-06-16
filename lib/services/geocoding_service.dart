import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/env.dart';
import '../models/geocoding_result.dart';

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  final Dio _dio = Dio();
  static const String _geocodeBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const String _placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';

  // Add debounce timer for search
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  // Initialize the service
  Future<void> initialize() async {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    // Add interceptor for logging in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => debugPrint('[Geocoding] $obj'),
      ));
    }
  }

  // Convert an address string to coordinates (forward geocoding)
  Future<List<GeocodingResult>> geocodeAddress(String address) async {
    if (address.trim().isEmpty) {
      throw GeocodingException('Address cannot be empty');
    }

    if (!Env.hasGoogleMapsKey) {
      throw GeocodingException('Google Maps API key not configured');
    }

    try {
      final response = await _dio.get(_geocodeBaseUrl, queryParameters: {
        'address': address,
        'key': Env.googleMapsApiKey,
        'components': 'country:DE', // Restrict to Germany, adjust as needed
      });

      if (response.statusCode != 200) {
        throw GeocodingException(
            'HTTP ${response.statusCode}: Failed to fetch geocoding data');
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'OK') {
        final results = data['results'] as List<dynamic>;
        return results
            .map((result) => GeocodingResult.fromGoogleMapsJson(
                result as Map<String, dynamic>))
            .toList();
      } else if (status == 'ZERO_RESULTS') {
        return [];
      } else {
        throw GeocodingException('Geocoding failed: $status');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GeocodingException(
            'Request timeout - check your internet connection');
      } else if (e.type == DioExceptionType.connectionError) {
        throw GeocodingException(
            'Connection error - check your internet connection');
      } else {
        throw GeocodingException('Network error: ${e.message}');
      }
    } catch (e) {
      if (e is GeocodingException) {
        rethrow;
      }
      throw GeocodingException('Unexpected error during geocoding: $e');
    }
  }

  // Convert coordinates to an address (reverse geocoding)
  Future<List<GeocodingResult>> reverseGeocode(LatLng coordinates) async {
    if (!Env.hasGoogleMapsKey) {
      throw GeocodingException('Google Maps API key not configured');
    }

    try {
      final response = await _dio.get(_geocodeBaseUrl, queryParameters: {
        'latlng': '${coordinates.latitude},${coordinates.longitude}',
        'key': Env.googleMapsApiKey,
        'result_type': 'street_address|route|establishment|point_of_interest',
      });

      if (response.statusCode != 200) {
        throw GeocodingException(
            'HTTP ${response.statusCode}: Failed to fetch reverse geocoding data');
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'OK') {
        final results = data['results'] as List<dynamic>;
        return results
            .map((result) => GeocodingResult.fromGoogleMapsJson(
                result as Map<String, dynamic>))
            .toList();
      } else if (status == 'ZERO_RESULTS') {
        return [];
      } else {
        throw GeocodingException('Reverse geocoding failed: $status');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GeocodingException(
            'Request timeout - check your internet connection');
      } else if (e.type == DioExceptionType.connectionError) {
        throw GeocodingException(
            'Connection error - check your internet connection');
      } else {
        throw GeocodingException('Network error: ${e.message}');
      }
    } catch (e) {
      if (e is GeocodingException) {
        rethrow;
      }
      throw GeocodingException('Unexpected error during reverse geocoding: $e');
    }
  }

  // Improved search for places by name or partial address using Places API
  Future<List<GeocodingResult>> searchPlaces(String query,
      {LatLng? bias}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    if (!Env.hasGoogleMapsKey) {
      throw GeocodingException('Google Maps API key not configured');
    }

    try {
      // Use autocomplete for better search results
      final response = await _dio.get(
        '$_placesBaseUrl/autocomplete/json',
        queryParameters: {
          'input': query.trim(),
          'key': Env.googleMapsApiKey,
          'components': 'country:de', // Restrict to Germany
          'types': 'establishment|geocode', // Include both POIs and addresses
          'language': 'en',
          if (bias != null) ...{
            'location': '${bias.latitude},${bias.longitude}',
            'radius': '10000', // Reduced to 10km for more local results
            'strictbounds': 'true', // Force results within the radius
          },
          'sessiontoken': DateTime.now()
              .millisecondsSinceEpoch
              .toString(), // For cost optimization
        },
      );

      if (response.statusCode != 200) {
        throw GeocodingException(
            'HTTP ${response.statusCode}: Failed to search places');
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'OK') {
        final predictions = data['predictions'] as List<dynamic>;
        final results = <GeocodingResult>[];

        // Convert predictions to geocoding results
        for (final prediction in predictions.take(15)) {
          // Get more results for sorting
          try {
            final predictionMap = prediction as Map<String, dynamic>;
            final placeId = predictionMap['place_id'] as String;

            // Get place details to get coordinates
            final placeDetails = await getPlaceDetails(placeId);
            if (placeDetails != null) {
              results.add(placeDetails);
            }
          } catch (e) {
            debugPrint('Error processing prediction: $e');
            // Continue with other predictions
          }
        }

        // Sort results by distance if bias location is provided
        if (bias != null && results.isNotEmpty) {
          results.sort((a, b) {
            final distanceA = _calculateDistance(bias, a.coordinates);
            final distanceB = _calculateDistance(bias, b.coordinates);
            return distanceA.compareTo(distanceB);
          });
        }

        // Return top 10 closest results
        return results.take(10).toList();
      } else if (status == 'ZERO_RESULTS') {
        // If no results with strict bounds, try again with broader search
        if (bias != null) {
          return await _searchPlacesWithFallback(query, bias);
        }
        return [];
      } else if (status == 'INVALID_REQUEST') {
        throw GeocodingException('Invalid search query');
      } else if (status == 'OVER_QUERY_LIMIT') {
        throw GeocodingException(
            'Search quota exceeded. Please try again later.');
      } else if (status == 'REQUEST_DENIED') {
        throw GeocodingException('Search service unavailable');
      } else {
        throw GeocodingException('Search failed: $status');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw GeocodingException(
            'Search timeout - check your internet connection');
      } else if (e.type == DioExceptionType.connectionError) {
        throw GeocodingException(
            'Connection error - check your internet connection');
      } else {
        throw GeocodingException('Network error during search: ${e.message}');
      }
    } catch (e) {
      if (e is GeocodingException) {
        rethrow;
      }
      debugPrint('Error searching places: $e');
      throw GeocodingException('Search error: $e');
    }
  }

  // Fallback search with broader radius if strict search returns no results
  Future<List<GeocodingResult>> _searchPlacesWithFallback(
      String query, LatLng bias) async {
    try {
      final response = await _dio.get(
        '$_placesBaseUrl/autocomplete/json',
        queryParameters: {
          'input': query.trim(),
          'key': Env.googleMapsApiKey,
          'components': 'country:de',
          'types': 'establishment|geocode',
          'language': 'en',
          'location': '${bias.latitude},${bias.longitude}',
          'radius': '50000', // 50km fallback radius
          'sessiontoken': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List<dynamic>;
          final results = <GeocodingResult>[];

          for (final prediction in predictions.take(15)) {
            try {
              final predictionMap = prediction as Map<String, dynamic>;
              final placeId = predictionMap['place_id'] as String;

              final placeDetails = await getPlaceDetails(placeId);
              if (placeDetails != null) {
                results.add(placeDetails);
              }
            } catch (e) {
              debugPrint('Error processing fallback prediction: $e');
            }
          }

          // Sort by distance and return closest results
          results.sort((a, b) {
            final distanceA = _calculateDistance(bias, a.coordinates);
            final distanceB = _calculateDistance(bias, b.coordinates);
            return distanceA.compareTo(distanceB);
          });

          return results.take(10).toList();
        }
      }
    } catch (e) {
      debugPrint('Fallback search failed: $e');
    }

    return [];
  }

  // Calculate distance between two LatLng points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double lat1Rad = point1.latitude * (3.141592653589793 / 180);
    final double lat2Rad = point2.latitude * (3.141592653589793 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Debounced search method for real-time search
  Future<List<GeocodingResult>> searchPlacesDebounced(
    String query, {
    LatLng? bias,
    required Function(List<GeocodingResult>) onResults,
    required Function(String) onError,
  }) async {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer
    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        final results = await searchPlaces(query, bias: bias);
        onResults(results);
      } catch (e) {
        onError(e.toString());
      }
    });

    return []; // Return empty list immediately
  }

  // Get detailed place information
  Future<GeocodingResult?> getPlaceDetails(String placeId) async {
    if (!Env.hasGoogleMapsKey) {
      throw GeocodingException('Google Maps API key not configured');
    }

    try {
      final response = await _dio.get(
        '$_placesBaseUrl/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields':
              'formatted_address,geometry,name,types,place_id,address_components',
          'key': Env.googleMapsApiKey,
          'language': 'en',
        },
      );

      if (response.statusCode != 200) {
        throw GeocodingException(
            'HTTP ${response.statusCode}: Failed to get place details');
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String;

      if (status == 'OK') {
        final result = data['result'] as Map<String, dynamic>;
        return GeocodingResult.fromPlaceDetailsJson(result);
      } else if (status == 'NOT_FOUND') {
        debugPrint('Place not found: $placeId');
        return null;
      } else {
        throw GeocodingException('Place details failed: $status');
      }
    } catch (e) {
      if (e is GeocodingException) {
        rethrow;
      }
      throw GeocodingException('Error getting place details: $e');
    }
  }

  // Validate if a coordinate is within a reasonable range
  bool isValidCoordinate(LatLng coordinate) {
    return coordinate.latitude >= -90 &&
        coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 &&
        coordinate.longitude <= 180;
  }

  // Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _dio.close();
  }
}

// Custom exception for geocoding errors
class GeocodingException implements Exception {
  final String message;
  const GeocodingException(this.message);

  @override
  String toString() => 'GeocodingException: $message';
}
