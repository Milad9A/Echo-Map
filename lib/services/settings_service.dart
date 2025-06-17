import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class SettingsData {
  final AppThemeMode themeMode;
  final bool highContrastMode;
  final bool largeFontSize;
  final bool reduceMotion;
  final int vibrationIntensity;
  final bool ttsEnabled;
  final String ttsRate;
  final double ttsVolume;
  final double ttsPitch;
  final String ttsLanguage;
  final bool announceStreetNames;
  final bool announceDistance;
  final bool announceHazards;
  final bool announceProgress;
  final int progressAnnouncementInterval; // in minutes

  const SettingsData({
    this.themeMode = AppThemeMode.system,
    this.highContrastMode = false,
    this.largeFontSize = false,
    this.reduceMotion = false,
    this.vibrationIntensity = 150,
    this.ttsEnabled = true,
    this.ttsRate = 'normal',
    this.ttsVolume = 0.8,
    this.ttsPitch = 1.0,
    this.ttsLanguage = 'en-US',
    this.announceStreetNames = true,
    this.announceDistance = true,
    this.announceHazards = true,
    this.announceProgress = true,
    this.progressAnnouncementInterval = 5,
  });

  SettingsData copyWith({
    AppThemeMode? themeMode,
    bool? highContrastMode,
    bool? largeFontSize,
    bool? reduceMotion,
    int? vibrationIntensity,
    bool? ttsEnabled,
    String? ttsRate,
    double? ttsVolume,
    double? ttsPitch,
    String? ttsLanguage,
    bool? announceStreetNames,
    bool? announceDistance,
    bool? announceHazards,
    bool? announceProgress,
    int? progressAnnouncementInterval,
  }) {
    return SettingsData(
      themeMode: themeMode ?? this.themeMode,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      largeFontSize: largeFontSize ?? this.largeFontSize,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      announceStreetNames: announceStreetNames ?? this.announceStreetNames,
      announceDistance: announceDistance ?? this.announceDistance,
      announceHazards: announceHazards ?? this.announceHazards,
      announceProgress: announceProgress ?? this.announceProgress,
      progressAnnouncementInterval:
          progressAnnouncementInterval ?? this.progressAnnouncementInterval,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themeMode': themeMode.index,
      'highContrastMode': highContrastMode,
      'largeFontSize': largeFontSize,
      'reduceMotion': reduceMotion,
      'vibrationIntensity': vibrationIntensity,
      'ttsEnabled': ttsEnabled,
      'ttsRate': ttsRate,
      'ttsVolume': ttsVolume,
      'ttsPitch': ttsPitch,
      'ttsLanguage': ttsLanguage,
      'announceStreetNames': announceStreetNames,
      'announceDistance': announceDistance,
      'announceHazards': announceHazards,
      'announceProgress': announceProgress,
      'progressAnnouncementInterval': progressAnnouncementInterval,
    };
  }

  factory SettingsData.fromMap(Map<String, dynamic> map) {
    try {
      return SettingsData(
        themeMode: AppThemeMode.values.elementAt((map['themeMode'] as int? ?? 0)
            .clamp(0, AppThemeMode.values.length - 1)),
        highContrastMode: map['highContrastMode'] as bool? ?? false,
        largeFontSize: map['largeFontSize'] as bool? ?? false,
        reduceMotion: map['reduceMotion'] as bool? ?? false,
        vibrationIntensity:
            (map['vibrationIntensity'] as int? ?? 150).clamp(50, 300),
        ttsEnabled: map['ttsEnabled'] as bool? ?? true,
        ttsRate: map['ttsRate'] as String? ?? 'normal',
        ttsVolume: (map['ttsVolume'] as double? ?? 0.8).clamp(0.0, 1.0),
        ttsPitch: (map['ttsPitch'] as double? ?? 1.0).clamp(0.5, 2.0),
        ttsLanguage: map['ttsLanguage'] as String? ?? 'en-US',
        announceStreetNames: map['announceStreetNames'] as bool? ?? true,
        announceDistance: map['announceDistance'] as bool? ?? true,
        announceHazards: map['announceHazards'] as bool? ?? true,
        announceProgress: map['announceProgress'] as bool? ?? true,
        progressAnnouncementInterval:
            (map['progressAnnouncementInterval'] as int? ?? 5).clamp(1, 60),
      );
    } catch (e) {
      debugPrint('Error parsing settings from map: $e');
      // Return default settings if parsing fails
      return const SettingsData();
    }
  }

  String toJson() {
    try {
      return jsonEncode(toMap());
    } catch (e) {
      debugPrint('Error encoding settings to JSON: $e');
      // Return default settings JSON if encoding fails
      return jsonEncode(const SettingsData().toMap());
    }
  }

  factory SettingsData.fromJson(String jsonString) {
    try {
      // Clean the JSON string first
      final cleanedJson = jsonString.trim();
      if (cleanedJson.isEmpty) {
        debugPrint('Empty JSON string, using defaults');
        return const SettingsData();
      }

      final Map<String, dynamic> map = jsonDecode(cleanedJson);
      return SettingsData.fromMap(map);
    } catch (e) {
      debugPrint('Error parsing settings from JSON: $e');
      debugPrint('JSON string: $jsonString');
      // Return default settings if JSON parsing fails
      return const SettingsData();
    }
  }
}

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _settingsKey =
      'app_settings_v2'; // Changed key to force reset
  static const String _legacySettingsKey = 'app_settings'; // Keep for migration

  SharedPreferences? _prefs;
  SettingsData _currentSettings = const SettingsData();

  final StreamController<SettingsData> _settingsController =
      StreamController<SettingsData>.broadcast();

  Stream<SettingsData> get settingsStream => _settingsController.stream;
  SettingsData get currentSettings => _currentSettings;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
    } catch (e) {
      debugPrint('Error initializing settings service: $e');
      // Use default settings if initialization fails
      _currentSettings = const SettingsData();
      _settingsController.add(_currentSettings);
    }
  }

  Future<void> _loadSettings() async {
    try {
      // Try to load from new key first
      String? settingsString = _prefs?.getString(_settingsKey);

      // If not found, try to migrate from legacy key
      if (settingsString == null) {
        settingsString = _prefs?.getString(_legacySettingsKey);
        if (settingsString != null) {
          debugPrint('Migrating settings from legacy key');
          // Save to new key and remove legacy
          await _prefs?.setString(_settingsKey, settingsString);
          await _prefs?.remove(_legacySettingsKey);
        }
      }

      if (settingsString != null && settingsString.isNotEmpty) {
        // Validate JSON format before parsing
        if (_isValidJson(settingsString)) {
          _currentSettings = SettingsData.fromJson(settingsString);
          debugPrint('Settings loaded successfully');
        } else {
          debugPrint('Invalid JSON format, using defaults');
          _currentSettings = const SettingsData();
          // Save defaults to fix corrupted settings
          await _saveSettings();
        }
      } else {
        debugPrint('No settings found, using defaults');
        _currentSettings = const SettingsData();
        // Save defaults for first time users
        await _saveSettings();
      }

      _settingsController.add(_currentSettings);
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Reset to defaults if loading fails
      _currentSettings = const SettingsData();
      _settingsController.add(_currentSettings);
      // Try to save defaults
      await _saveSettings();
    }
  }

  bool _isValidJson(String jsonString) {
    try {
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settingsJson = _currentSettings.toJson();

      // Validate the JSON before saving
      if (_isValidJson(settingsJson)) {
        await _prefs?.setString(_settingsKey, settingsJson);
        _settingsController.add(_currentSettings);
        debugPrint('Settings saved successfully');
      } else {
        debugPrint('Failed to save settings: Invalid JSON generated');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      // Don't throw the error, just log it
    }
  }

  // Helper method to safely update settings
  Future<void> _updateSettings(SettingsData newSettings) async {
    try {
      _currentSettings = newSettings;
      await _saveSettings();
    } catch (e) {
      debugPrint('Error updating settings: $e');
      // Revert to previous settings if update fails
      _settingsController.add(_currentSettings);
    }
  }

  // Theme settings
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _updateSettings(_currentSettings.copyWith(themeMode: mode));
  }

  Future<void> setHighContrastMode(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(highContrastMode: enabled));
  }

  Future<void> setLargeFontSize(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(largeFontSize: enabled));
  }

  Future<void> setReduceMotion(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(reduceMotion: enabled));
  }

  // Vibration settings
  Future<void> setVibrationIntensity(int intensity) async {
    // Validate intensity range
    final clampedIntensity = intensity.clamp(50, 300);
    await _updateSettings(
        _currentSettings.copyWith(vibrationIntensity: clampedIntensity));
  }

  // TTS settings
  Future<void> setTtsEnabled(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(ttsEnabled: enabled));
  }

  Future<void> setTtsRate(String rate) async {
    // Validate rate value
    final validRates = ['slow', 'normal', 'fast'];
    final validatedRate = validRates.contains(rate) ? rate : 'normal';
    await _updateSettings(_currentSettings.copyWith(ttsRate: validatedRate));
  }

  Future<void> setTtsVolume(double volume) async {
    // Validate volume range
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _updateSettings(_currentSettings.copyWith(ttsVolume: clampedVolume));
  }

  Future<void> setTtsPitch(double pitch) async {
    // Validate pitch range
    final clampedPitch = pitch.clamp(0.5, 2.0);
    await _updateSettings(_currentSettings.copyWith(ttsPitch: clampedPitch));
  }

  Future<void> setTtsLanguage(String language) async {
    await _updateSettings(_currentSettings.copyWith(ttsLanguage: language));
  }

  Future<void> setAnnounceStreetNames(bool enabled) async {
    await _updateSettings(
        _currentSettings.copyWith(announceStreetNames: enabled));
  }

  Future<void> setAnnounceDistance(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(announceDistance: enabled));
  }

  Future<void> setAnnounceHazards(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(announceHazards: enabled));
  }

  Future<void> setAnnounceProgress(bool enabled) async {
    await _updateSettings(_currentSettings.copyWith(announceProgress: enabled));
  }

  Future<void> setProgressAnnouncementInterval(int minutes) async {
    // Validate interval range
    final clampedInterval = minutes.clamp(1, 60);
    await _updateSettings(_currentSettings.copyWith(
        progressAnnouncementInterval: clampedInterval));
  }

  Future<void> resetToDefaults() async {
    try {
      _currentSettings = const SettingsData();
      await _saveSettings();
      debugPrint('Settings reset to defaults');
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }

  // Clear all settings (for debugging)
  Future<void> clearAllSettings() async {
    try {
      await _prefs?.remove(_settingsKey);
      await _prefs?.remove(_legacySettingsKey);
      _currentSettings = const SettingsData();
      _settingsController.add(_currentSettings);
      debugPrint('All settings cleared');
    } catch (e) {
      debugPrint('Error clearing settings: $e');
    }
  }

  // Export settings as JSON string (for backup)
  String exportSettings() {
    return _currentSettings.toJson();
  }

  // Import settings from JSON string (for restore)
  Future<bool> importSettings(String jsonString) async {
    try {
      final importedSettings = SettingsData.fromJson(jsonString);
      await _updateSettings(importedSettings);
      debugPrint('Settings imported successfully');
      return true;
    } catch (e) {
      debugPrint('Error importing settings: $e');
      return false;
    }
  }

  void dispose() {
    _settingsController.close();
  }
}
