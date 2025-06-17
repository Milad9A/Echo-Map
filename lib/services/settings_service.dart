import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_config.dart';

class SettingsData {
  final bool highContrastMode;
  final bool largeFontSize;
  final bool reduceMotion;
  final int vibrationIntensity;
  final bool speakInstructions;
  final bool enableVoiceCommands;
  final AppThemeMode themeMode;

  // Add text-to-speech settings
  final bool ttsEnabled;
  final double ttsVolume;
  final double ttsPitch;
  final String ttsRate; // 'slow', 'normal', 'fast'

  const SettingsData({
    this.highContrastMode = false,
    this.largeFontSize = false,
    this.reduceMotion = false,
    this.vibrationIntensity = 128,
    this.speakInstructions = true,
    this.enableVoiceCommands = true,
    this.themeMode = AppThemeMode.system,
    this.ttsEnabled = true,
    this.ttsVolume = 1.0,
    this.ttsPitch = 1.0,
    this.ttsRate = 'normal',
  });

  SettingsData copyWith({
    bool? highContrastMode,
    bool? largeFontSize,
    bool? reduceMotion,
    int? vibrationIntensity,
    bool? speakInstructions,
    bool? enableVoiceCommands,
    AppThemeMode? themeMode,
    bool? ttsEnabled,
    double? ttsVolume,
    double? ttsPitch,
    String? ttsRate,
  }) {
    return SettingsData(
      highContrastMode: highContrastMode ?? this.highContrastMode,
      largeFontSize: largeFontSize ?? this.largeFontSize,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      speakInstructions: speakInstructions ?? this.speakInstructions,
      enableVoiceCommands: enableVoiceCommands ?? this.enableVoiceCommands,
      themeMode: themeMode ?? this.themeMode,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsRate: ttsRate ?? this.ttsRate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'highContrastMode': highContrastMode,
      'largeFontSize': largeFontSize,
      'reduceMotion': reduceMotion,
      'vibrationIntensity': vibrationIntensity,
      'speakInstructions': speakInstructions,
      'enableVoiceCommands': enableVoiceCommands,
      'themeMode': themeMode.index,
      'ttsEnabled': ttsEnabled,
      'ttsVolume': ttsVolume,
      'ttsPitch': ttsPitch,
      'ttsRate': ttsRate,
    };
  }

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    return SettingsData(
      highContrastMode: json['highContrastMode'] ?? false,
      largeFontSize: json['largeFontSize'] ?? false,
      reduceMotion: json['reduceMotion'] ?? false,
      vibrationIntensity: json['vibrationIntensity'] ?? 128,
      speakInstructions: json['speakInstructions'] ?? true,
      enableVoiceCommands: json['enableVoiceCommands'] ?? true,
      themeMode:
          AppThemeMode.values[json['themeMode'] ?? AppThemeMode.system.index],
      ttsEnabled: json['ttsEnabled'] ?? true,
      ttsVolume: (json['ttsVolume'] ?? 1.0).toDouble(),
      ttsPitch: (json['ttsPitch'] ?? 1.0).toDouble(),
      ttsRate: json['ttsRate'] ?? 'normal',
    );
  }
}

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _settingsKey = 'app_settings';

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
      debugPrint('SettingsService initialized');
    } catch (e) {
      debugPrint('Error initializing SettingsService: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final String? settingsJson = _prefs?.getString(_settingsKey);
      if (settingsJson != null) {
        // Parse JSON and create SettingsData
        final Map<String, dynamic> settingsMap = {};
        // Simple parsing implementation
        final parts = settingsJson.split(',');
        for (final part in parts) {
          final keyValue = part.split(':');
          if (keyValue.length == 2) {
            final key = keyValue[0].trim().replaceAll('"', '');
            final value = keyValue[1].trim().replaceAll('"', '');

            if (value == 'true' || value == 'false') {
              settingsMap[key] = value == 'true';
            } else if (int.tryParse(value) != null) {
              settingsMap[key] = int.parse(value);
            } else {
              settingsMap[key] = value;
            }
          }
        }

        _currentSettings = SettingsData.fromJson(settingsMap);
      }
      _settingsController.add(_currentSettings);
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settingsJson = _currentSettings.toJson().toString();
      await _prefs?.setString(_settingsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> setHighContrastMode(bool enabled) async {
    _currentSettings = _currentSettings.copyWith(highContrastMode: enabled);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setLargeFontSize(bool enabled) async {
    _currentSettings = _currentSettings.copyWith(largeFontSize: enabled);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setReduceMotion(bool enabled) async {
    _currentSettings = _currentSettings.copyWith(reduceMotion: enabled);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setVibrationIntensity(int intensity) async {
    _currentSettings = _currentSettings.copyWith(vibrationIntensity: intensity);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setSpeakInstructions(bool enabled) async {
    _currentSettings = _currentSettings.copyWith(speakInstructions: enabled);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setEnableVoiceCommands(bool enabled) async {
    _currentSettings = _currentSettings.copyWith(enableVoiceCommands: enabled);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    _currentSettings = _currentSettings.copyWith(themeMode: themeMode);
    await _saveSettings();
    _settingsController.add(_currentSettings);
    debugPrint('Theme mode set to: ${themeMode.displayName}');
  }

  Future<void> setTtsEnabled(bool enabled) async {
    _currentSettings = _currentSettings.copyWith(ttsEnabled: enabled);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setTtsVolume(double volume) async {
    _currentSettings = _currentSettings.copyWith(ttsVolume: volume);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setTtsPitch(double pitch) async {
    _currentSettings = _currentSettings.copyWith(ttsPitch: pitch);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> setTtsRate(String rate) async {
    _currentSettings = _currentSettings.copyWith(ttsRate: rate);
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  Future<void> resetToDefaults() async {
    _currentSettings = const SettingsData();
    await _saveSettings();
    _settingsController.add(_currentSettings);
  }

  void dispose() {
    _settingsController.close();
  }
}
