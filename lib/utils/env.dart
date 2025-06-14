import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A utility class to access environment variables
class Env {
  /// Get the Google Maps API key from environment variables
  static String get googleMapsApiKey {
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }

  /// Check if an API key is available
  static bool get hasGoogleMapsKey {
    final key = googleMapsApiKey;
    return key.isNotEmpty;
  }
}
