import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  final StreamController<SettingsData> _settingsController =
      StreamController<SettingsData>.broadcast();

  // Settings keys
  static const String _keyHighContrastMode = 'high_contrast_mode';
  static const String _keyLargeFontSize = 'large_font_size';
  static const String _keyReduceMotion = 'reduce_motion';
  static const String _keyVibrationIntensity = 'vibration_intensity';
  static const String _keySpeakInstructions = 'speak_instructions';
  static const String _keyEnableVoiceCommands = 'enable_voice_commands';

  // Default values
  static const bool _defaultHighContrastMode = false;
  static const bool _defaultLargeFontSize = false;
  static const bool _defaultReduceMotion = false;
  static const int _defaultVibrationIntensity = 128; // medium intensity
  static const bool _defaultSpeakInstructions = true;
  static const bool _defaultEnableVoiceCommands = true;

  // Current settings
  SettingsData _currentSettings = const SettingsData();

  // Public streams
  Stream<SettingsData> get settingsStream => _settingsController.stream;

  // Getters
  SettingsData get currentSettings => _currentSettings;

  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      debugPrint('SettingsService initialized');
    } catch (e) {
      debugPrint('Error initializing SettingsService: $e');
    }
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    try {
      _currentSettings = SettingsData(
        highContrastMode:
            _prefs?.getBool(_keyHighContrastMode) ?? _defaultHighContrastMode,
        largeFontSize:
            _prefs?.getBool(_keyLargeFontSize) ?? _defaultLargeFontSize,
        reduceMotion: _prefs?.getBool(_keyReduceMotion) ?? _defaultReduceMotion,
        vibrationIntensity: _prefs?.getInt(_keyVibrationIntensity) ??
            _defaultVibrationIntensity,
        speakInstructions:
            _prefs?.getBool(_keySpeakInstructions) ?? _defaultSpeakInstructions,
        enableVoiceCommands: _prefs?.getBool(_keyEnableVoiceCommands) ??
            _defaultEnableVoiceCommands,
      );

      _settingsController.add(_currentSettings);
      debugPrint('Settings loaded: $_currentSettings');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Update high contrast mode
  Future<void> setHighContrastMode(bool value) async {
    try {
      await _prefs?.setBool(_keyHighContrastMode, value);
      _currentSettings = _currentSettings.copyWith(highContrastMode: value);
      _settingsController.add(_currentSettings);
      debugPrint('High contrast mode updated: $value');
    } catch (e) {
      debugPrint('Error saving high contrast mode: $e');
    }
  }

  // Update large font size
  Future<void> setLargeFontSize(bool value) async {
    try {
      await _prefs?.setBool(_keyLargeFontSize, value);
      _currentSettings = _currentSettings.copyWith(largeFontSize: value);
      _settingsController.add(_currentSettings);
      debugPrint('Large font size updated: $value');
    } catch (e) {
      debugPrint('Error saving large font size: $e');
    }
  }

  // Update reduce motion
  Future<void> setReduceMotion(bool value) async {
    try {
      await _prefs?.setBool(_keyReduceMotion, value);
      _currentSettings = _currentSettings.copyWith(reduceMotion: value);
      _settingsController.add(_currentSettings);
      debugPrint('Reduce motion updated: $value');
    } catch (e) {
      debugPrint('Error saving reduce motion: $e');
    }
  }

  // Update vibration intensity
  Future<void> setVibrationIntensity(int value) async {
    try {
      await _prefs?.setInt(_keyVibrationIntensity, value);
      _currentSettings = _currentSettings.copyWith(vibrationIntensity: value);
      _settingsController.add(_currentSettings);
      debugPrint('Vibration intensity updated: $value');
    } catch (e) {
      debugPrint('Error saving vibration intensity: $e');
    }
  }

  // Update speak instructions
  Future<void> setSpeakInstructions(bool value) async {
    try {
      await _prefs?.setBool(_keySpeakInstructions, value);
      _currentSettings = _currentSettings.copyWith(speakInstructions: value);
      _settingsController.add(_currentSettings);
      debugPrint('Speak instructions updated: $value');
    } catch (e) {
      debugPrint('Error saving speak instructions: $e');
    }
  }

  // Update enable voice commands
  Future<void> setEnableVoiceCommands(bool value) async {
    try {
      await _prefs?.setBool(_keyEnableVoiceCommands, value);
      _currentSettings = _currentSettings.copyWith(enableVoiceCommands: value);
      _settingsController.add(_currentSettings);
      debugPrint('Enable voice commands updated: $value');
    } catch (e) {
      debugPrint('Error saving enable voice commands: $e');
    }
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      await _prefs?.clear();
      await _loadSettings();
      debugPrint('Settings reset to defaults');
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _settingsController.close();
  }
}

// Settings data class
class SettingsData {
  final bool highContrastMode;
  final bool largeFontSize;
  final bool reduceMotion;
  final int vibrationIntensity;
  final bool speakInstructions;
  final bool enableVoiceCommands;

  const SettingsData({
    this.highContrastMode = false,
    this.largeFontSize = false,
    this.reduceMotion = false,
    this.vibrationIntensity = 128,
    this.speakInstructions = true,
    this.enableVoiceCommands = true,
  });

  SettingsData copyWith({
    bool? highContrastMode,
    bool? largeFontSize,
    bool? reduceMotion,
    int? vibrationIntensity,
    bool? speakInstructions,
    bool? enableVoiceCommands,
  }) {
    return SettingsData(
      highContrastMode: highContrastMode ?? this.highContrastMode,
      largeFontSize: largeFontSize ?? this.largeFontSize,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      speakInstructions: speakInstructions ?? this.speakInstructions,
      enableVoiceCommands: enableVoiceCommands ?? this.enableVoiceCommands,
    );
  }

  @override
  String toString() {
    return 'SettingsData{highContrastMode: $highContrastMode, largeFontSize: $largeFontSize, '
        'reduceMotion: $reduceMotion, vibrationIntensity: $vibrationIntensity, '
        'speakInstructions: $speakInstructions, enableVoiceCommands: $enableVoiceCommands}';
  }
}
