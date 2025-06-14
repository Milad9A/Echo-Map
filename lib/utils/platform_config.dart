import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'env.dart';

/// Utility for platform-specific configuration
class PlatformConfig {
  static const MethodChannel _channel = MethodChannel(
    'com.echomap/environment',
  );

  // Track initialization status
  static bool _initialized = false;
  static bool get isInitialized => _initialized;
  static bool _isConfiguring = false;

  /// Configure platform-specific settings (e.g., API keys)
  static Future<void> configure() async {
    if (_initialized) {
      debugPrint('Platform configuration already initialized');
      return;
    }

    // Prevent concurrent initialization
    if (_isConfiguring) {
      debugPrint('Platform configuration already in progress');
      return;
    }

    _isConfiguring = true;

    try {
      // Only attempt to configure if we have a valid API key
      if (Env.hasGoogleMapsKey) {
        // iOS requires setting API key via method channel
        if (Platform.isIOS) {
          try {
            debugPrint('Configuring Google Maps API key for iOS');
            await _channel
                .invokeMethod('setGoogleMapsApiKey', {
                  'apiKey': Env.googleMapsApiKey,
                })
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    debugPrint(
                      'Google Maps API key configuration timed out, continuing anyway',
                    );
                    return null;
                  },
                );
            debugPrint('Configured Google Maps API key for iOS');

            // Give iOS extra time to process the API key
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            // Don't fail if the method channel call fails
            // as we've already set the API key in AppDelegate
            debugPrint('Note: Method channel config call returned: $e');
            debugPrint('This is expected if the map was already initialized');
          }
        } else if (Platform.isAndroid) {
          // Android configuration is handled via the manifest
          debugPrint('Using Google Maps API key from Android resources');
        }

        // Allow a moment for the configuration to take effect
        await Future.delayed(const Duration(milliseconds: 200));
        _initialized = true;
      } else {
        debugPrint(
          'Warning: No Google Maps API key found in environment variables',
        );
      }
    } catch (e) {
      // Log error but don't crash
      debugPrint('Error configuring platform settings: $e');
    } finally {
      _isConfiguring = false;
    }
  }
}
