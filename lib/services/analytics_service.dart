import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver _observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  static FirebaseAnalytics get analytics => _analytics;
  static FirebaseAnalyticsObserver get observer => _observer;

  /// Initialize Analytics
  static Future<void> initialize() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  /// Log navigation events
  static Future<void> logNavigation(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  /// Log route calculation events
  static Future<void> logRouteCalculation({
    required String origin,
    required String destination,
    required double distance,
    required int duration,
  }) async {
    await _analytics.logEvent(
      name: 'route_calculated',
      parameters: {
        'origin': origin,
        'destination': destination,
        'distance_km': distance,
        'duration_minutes': duration,
      },
    );
  }

  /// Log navigation start
  static Future<void> logNavigationStart({
    required String destination,
    required double distance,
  }) async {
    await _analytics.logEvent(
      name: 'navigation_started',
      parameters: {
        'destination': destination,
        'distance_km': distance,
      },
    );
  }

  /// Log navigation completion
  static Future<void> logNavigationComplete({
    required String destination,
    required int duration,
  }) async {
    await _analytics.logEvent(
      name: 'navigation_completed',
      parameters: {
        'destination': destination,
        'duration_minutes': duration,
      },
    );
  }

  /// Log vibration pattern usage
  static Future<void> logVibrationPattern(String patternName) async {
    await _analytics.logEvent(
      name: 'vibration_pattern_used',
      parameters: {
        'pattern_name': patternName,
      },
    );
  }

  /// Log accessibility feature usage
  static Future<void> logAccessibilityFeature(String featureName) async {
    await _analytics.logEvent(
      name: 'accessibility_feature_used',
      parameters: {
        'feature_name': featureName,
      },
    );
  }

  /// Log settings changes
  static Future<void> logSettingsChange(
      String settingName, String value) async {
    await _analytics.logEvent(
      name: 'settings_changed',
      parameters: {
        'setting_name': settingName,
        'setting_value': value,
      },
    );
  }

  /// Log error events
  static Future<void> logError(String errorType, String errorMessage) async {
    await _analytics.logEvent(
      name: 'error_occurred',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
      },
    );
  }

  /// Log app performance events
  static Future<void> logPerformance(String action, int duration) async {
    await _analytics.logEvent(
      name: 'performance_metric',
      parameters: {
        'action': action,
        'duration_ms': duration,
      },
    );
  }
}
