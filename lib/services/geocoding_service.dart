import 'dart:async';
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
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  // Initialize the service
  Future<void> initialize() async {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

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
      final response = await _dio.get(_baseUrl, queryParameters: {
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
      final response = await _dio.get(_baseUrl, queryParameters: {
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

  // Search for places by name or partial address
  Future<List<GeocodingResult>> searchPlaces(String query,
      {LatLng? bias}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final queryParameters = <String, dynamic>{
        'address': query,
        'key': Env.googleMapsApiKey,
        'components': 'country:DE', // Restrict to Germany
      };

      // Add location bias if provided (prioritize results near this location)
      if (bias != null) {
        queryParameters['region'] = 'de';
        queryParameters['bounds'] =
            '${bias.latitude - 0.1},${bias.longitude - 0.1}|'
            '${bias.latitude + 0.1},${bias.longitude + 0.1}';
      }

      final response =
          await _dio.get(_baseUrl, queryParameters: queryParameters);

      if (response.statusCode != 200) {
        throw GeocodingException(
            'HTTP ${response.statusCode}: Failed to search places');
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
        throw GeocodingException('Place search failed: $status');
      }
    } catch (e) {
      if (e is GeocodingException) {
        rethrow;
      }
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  // Get detailed place information
  Future<GeocodingResult?> getPlaceDetails(String placeId) async {
    if (!Env.hasGoogleMapsKey) {
      throw GeocodingException('Google Maps API key not configured');
    }

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'formatted_address,geometry,name,types',
          'key': Env.googleMapsApiKey,
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
