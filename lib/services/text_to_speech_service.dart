import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechRate { slow, normal, fast }

class TextToSpeechService {
  // Singleton pattern
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;
  TextToSpeechService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _isSpeaking = false;

  // Default settings
  double _volume = 0.8;
  double _pitch = 1.0;
  SpeechRate _speechRate = SpeechRate.normal;
  String _language = 'en-US';

  // Stream controllers for events
  final StreamController<bool> _speakingController = StreamController<bool>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  // Public streams
  Stream<bool> get speakingStream => _speakingController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  double get volume => _volume;
  double get pitch => _pitch;
  SpeechRate get speechRate => _speechRate;
  String get language => _language;

  // Initialize TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _flutterTts = FlutterTts();

      // Configure TTS settings
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setPitch(_pitch);
      await _flutterTts!.setSpeechRate(_getSpeechRateValue(_speechRate));
      await _flutterTts!.setLanguage(_language);

      // Set up event handlers
      _flutterTts!.setStartHandler(() {
        _isSpeaking = true;
        _speakingController.add(true);
      });

      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingController.add(false);
      });

      _flutterTts!.setErrorHandler((message) {
        _isSpeaking = false;
        _speakingController.add(false);
        _errorController.add(message);
        debugPrint('TTS Error: $message');
      });

      _flutterTts!.setCancelHandler(() {
        _isSpeaking = false;
        _speakingController.add(false);
      });

      _isInitialized = true;
      debugPrint('TTS Service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize TTS: $e');
      _errorController.add('Failed to initialize TTS: $e');
      return false;
    }
  }

  // Speak text
  Future<void> speak(String text) async {
    if (!_isInitialized || !_isEnabled || text.trim().isEmpty) {
      return;
    }

    try {
      // Stop any current speech
      await stop();

      // Clean the text for better speech
      final cleanText = _cleanTextForSpeech(text);

      debugPrint('TTS Speaking: $cleanText');
      await _flutterTts!.speak(cleanText);
    } catch (e) {
      debugPrint('Error speaking text: $e');
      _errorController.add('Error speaking text: $e');
    }
  }

  // Stop current speech
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts!.stop();
      _isSpeaking = false;
      _speakingController.add(false);
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  // Pause speech (if supported)
  Future<void> pause() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts!.pause();
    } catch (e) {
      debugPrint('Error pausing TTS: $e');
    }
  }

  // Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    if (_isInitialized) {
      try {
        await _flutterTts!.setVolume(_volume);
      } catch (e) {
        debugPrint('Error setting TTS volume: $e');
      }
    }
  }

  // Set pitch (0.5 to 2.0, 1.0 is normal)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);

    if (_isInitialized) {
      try {
        await _flutterTts!.setPitch(_pitch);
      } catch (e) {
        debugPrint('Error setting TTS pitch: $e');
      }
    }
  }

  // Set speech rate
  Future<void> setSpeechRate(SpeechRate rate) async {
    _speechRate = rate;

    if (_isInitialized) {
      try {
        await _flutterTts!.setSpeechRate(_getSpeechRateValue(rate));
      } catch (e) {
        debugPrint('Error setting TTS speech rate: $e');
      }
    }
  }

  // Set language
  Future<void> setLanguage(String language) async {
    _language = language;

    if (_isInitialized) {
      try {
        await _flutterTts!.setLanguage(_language);
      } catch (e) {
        debugPrint('Error setting TTS language: $e');
      }
    }
  }

  // Enable/disable TTS
  void setEnabled(bool enabled) {
    _isEnabled = enabled;

    if (!enabled && _isSpeaking) {
      stop();
    }
  }

  // Get available languages
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) return [];

    try {
      final languages = await _flutterTts!.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      debugPrint('Error getting available languages: $e');
      return [];
    }
  }

  // Check if TTS is available
  Future<bool> isAvailable() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  // Navigation-specific announcements
  Future<void> announceNavigation(String destination) async {
    await speak('Starting navigation to $destination');
  }

  Future<void> announceTurn(String direction, {String? streetName, int? distance}) async {
    String announcement = '';

    if (distance != null && distance > 0) {
      if (distance < 100) {
        announcement = 'In $distance meters, ';
      } else {
        final distanceText = distance < 1000
            ? '$distance meters'
            : '${(distance / 1000).toStringAsFixed(1)} kilometers';
        announcement = 'In $distanceText, ';
      }
    }

    switch (direction.toLowerCase()) {
      case 'left':
      case 'slight_left':
        announcement += direction.contains('slight') ? 'turn slightly left' : 'turn left';
        break;
      case 'right':
      case 'slight_right':
        announcement += direction.contains('slight') ? 'turn slightly right' : 'turn right';
        break;
      case 'sharp_left':
        announcement += 'make a sharp left turn';
        break;
      case 'sharp_right':
        announcement += 'make a sharp right turn';
        break;
      case 'uturn':
        announcement += 'make a U-turn';
        break;
      case 'straight':
      case 'continue':
        announcement += 'continue straight';
        break;
      case 'merge':
        announcement += 'merge';
        break;
      case 'exit':
        announcement += 'take the exit';
        break;
      default:
        announcement += 'turn $direction';
    }

    if (streetName != null && streetName.isNotEmpty) {
      announcement += ' onto $streetName';
    }

    await speak(announcement);
  }

  Future<void> announceDestinationReached() async {
    await speak('Destination reached. You have arrived.');
  }

  Future<void> announceOffRoute() async {
    await speak('You are off route. Recalculating.');
  }

  Future<void> announceOnRoute() async {
    await speak('Back on route.');
  }

  Future<void> announceCrossing({String? streetName, String? crossingType}) async {
    String announcement = 'Street crossing ahead';

    if (crossingType != null) {
      switch (crossingType.toLowerCase()) {
        case 'traffic_light':
          announcement = 'Traffic light crossing ahead';
          break;
        case 'zebra':
          announcement = 'Zebra crossing ahead';
          break;
        case 'uncontrolled':
          announcement = 'Uncontrolled crossing ahead';
          break;
      }
    }

    if (streetName != null && streetName.isNotEmpty) {
      announcement += ' on $streetName';
    }

    await speak(announcement);
  }

  Future<void> announceHazard(String hazardType, {String? description}) async {
    String announcement = 'Caution, ';

    switch (hazardType.toLowerCase()) {
      case 'construction':
        announcement += 'construction ahead';
        break;
      case 'obstacle':
        announcement += 'obstacle on path';
        break;
      case 'wet_surface':
        announcement += 'wet surface ahead';
        break;
      case 'narrow_path':
        announcement += 'narrow path ahead';
        break;
      case 'steep_incline':
        announcement += 'steep incline ahead';
        break;
      case 'poor_lighting':
        announcement += 'poor lighting ahead';
        break;
      default:
        announcement += 'hazard ahead';
    }

    if (description != null && description.isNotEmpty) {
      announcement += '. $description';
    }

    await speak(announcement);
  }

  Future<void> announceEmergency(String emergencyType, String action) async {
    String announcement = 'Emergency: ';

    switch (action.toLowerCase()) {
      case 'stop':
        announcement += 'Navigation stopped due to emergency';
        break;
      case 'reroute':
        announcement += 'Emergency reroute in progress';
        break;
      case 'detour':
        announcement += 'Creating emergency detour';
        break;
      case 'pause':
        announcement += 'Navigation paused for safety';
        break;
      default:
        announcement += 'Emergency situation detected';
    }

    await speak(announcement);
  }

  Future<void> announceProgress({int? distanceRemaining, int? timeRemaining}) async {
    if (distanceRemaining == null && timeRemaining == null) return;

    String announcement = '';

    if (distanceRemaining != null) {
      if (distanceRemaining < 1000) {
        announcement = '$distanceRemaining meters remaining';
      } else {
        final km = (distanceRemaining / 1000.0).toStringAsFixed(1);
        announcement = '$km kilometers remaining';
      }
    }

    if (timeRemaining != null) {
      final minutes = (timeRemaining / 60).round();
      final timeText = minutes < 60
          ? '$minutes minutes'
          : '${minutes ~/ 60} hours and ${minutes % 60} minutes';

      if (announcement.isNotEmpty) {
        announcement += ', approximately $timeText';
      } else {
        announcement = 'Approximately $timeText remaining';
      }
    }

    await speak(announcement);
  }

  // Convert speech rate enum to flutter_tts value
  double _getSpeechRateValue(SpeechRate rate) {
    switch (rate) {
      case SpeechRate.slow:
        return 0.4;
      case SpeechRate.normal:
        return 0.6;
      case SpeechRate.fast:
        return 0.8;
    }
  }

  // Clean text for better speech output
  String _cleanTextForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', 'and')
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single space
        .trim();
  }

  // Dispose resources
  void dispose() {
    stop();
    _speakingController.close();
    _errorController.close();
    _flutterTts = null;
    _isInitialized = false;
  }
}
