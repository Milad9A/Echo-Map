import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'env.dart';

/// Utility for platform-specific configuration
class PlatformConfig {
  static const MethodChannel _channel = MethodChannel(
    'com.echomap/environment',
  );

  /// Configure platform-specific settings (e.g., API keys)
  static Future<void> configure() async {
    try {
      // Only attempt to configure if we have a valid API key
      if (Env.hasGoogleMapsKey) {
        // iOS requires setting API key via method channel
        if (Platform.isIOS) {
          await _channel.invokeMethod('setGoogleMapsApiKey', {
            'apiKey': Env.googleMapsApiKey,
          });
          print('Configured Google Maps API key for iOS');
        }
      } else {
        print('Warning: No Google Maps API key found in environment variables');
      }
    } catch (e) {
      // Log error but don't crash
      print('Error configuring platform settings: $e');
    }
  }
}
