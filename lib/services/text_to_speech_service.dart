import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechRate { slow, normal, fast }

class TextToSpeechService {
  // Singleton pattern
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;
  TextToSpeechService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isEnabled = true;
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5; // Default rate (normal)

  // Stream controllers
  final StreamController<String> _spokenTextController =
      StreamController<String>.broadcast();
  final StreamController<bool> _speakingStatusController =
      StreamController<bool>.broadcast();

  // Public streams
  Stream<String> get spokenTextStream => _spokenTextController.stream;
  Stream<bool> get speakingStatusStream => _speakingStatusController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  bool get isEnabled => _isEnabled;

  // Initialize the TTS engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Configure the TTS engine
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setLanguage('en-US');

      // Set up completion listeners
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingStatusController.add(false);
      });

      _flutterTts.setErrorHandler((error) {
        debugPrint('TTS Error: $error');
        _isSpeaking = false;
        _speakingStatusController.add(false);
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      return false;
    }
  }

  // Speak a given text
  Future<bool> speak(String text) async {
    if (!_isEnabled) return false;
    if (!_isInitialized) await initialize();

    try {
      // Stop any ongoing speech
      if (_isSpeaking) {
        await stop();
      }

      _isSpeaking = true;
      _isPaused = false;
      _speakingStatusController.add(true);
      _spokenTextController.add(text);

      await _flutterTts.speak(text);
      return true;
    } catch (e) {
      debugPrint('Error speaking text: $e');
      _isSpeaking = false;
      _speakingStatusController.add(false);
      return false;
    }
  }

  // Stop speaking
  Future<bool> stop() async {
    if (!_isInitialized) return false;

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _isPaused = false;
      _speakingStatusController.add(false);
      return true;
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
      return false;
    }
  }

  // Pause speaking
  Future<bool> pause() async {
    if (!_isInitialized || !_isSpeaking || _isPaused) return false;

    try {
      // Check if pause is supported on the platform
      final available = await _flutterTts.pause();
      if (available == 1) {
        _isPaused = true;
        _speakingStatusController.add(false);
        return true;
      } else {
        // If pause is not supported, just stop
        return await stop();
      }
    } catch (e) {
      debugPrint('Error pausing TTS: $e');
      return false;
    }
  }

  // Set speech volume (0.0 to 1.0)
  Future<bool> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) return false;

    _volume = volume;
    if (_isInitialized) {
      await _flutterTts.setVolume(volume);
    }
    return true;
  }

  // Set speech pitch (0.5 to 2.0)
  Future<bool> setPitch(double pitch) async {
    if (pitch < 0.5 || pitch > 2.0) return false;

    _pitch = pitch;
    if (_isInitialized) {
      await _flutterTts.setPitch(pitch);
    }
    return true;
  }

  // Set speech rate using predefined rates
  Future<bool> setSpeechRate(SpeechRate rate) async {
    double numericRate;

    switch (rate) {
      case SpeechRate.slow:
        numericRate = 0.3;
        break;
      case SpeechRate.normal:
        numericRate = 0.5;
        break;
      case SpeechRate.fast:
        numericRate = 0.7;
        break;
    }

    _rate = numericRate;
    if (_isInitialized) {
      await _flutterTts.setSpeechRate(numericRate);
    }
    return true;
  }

  // Enable or disable speech
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _isSpeaking) {
      stop();
    }
  }

  // Format navigation step for speech
  String formatNavigationStep(String instruction, int? distance) {
    if (distance == null) {
      return instruction;
    }

    String distanceText;
    if (distance < 100) {
      distanceText = 'In $distance meters';
    } else if (distance < 1000) {
      distanceText = 'In ${(distance / 100).floor() * 100} meters';
    } else {
      final km = distance / 1000.0;
      distanceText = 'In ${km.toStringAsFixed(1)} kilometers';
    }

    return '$distanceText, $instruction';
  }

  // Speak turn direction with distance
  Future<bool> speakTurn(String turnDirection, int? distance) {
    String instruction;

    switch (turnDirection.toLowerCase()) {
      case 'left':
        instruction = 'Turn left';
        break;
      case 'right':
        instruction = 'Turn right';
        break;
      case 'slight left':
        instruction = 'Turn slightly left';
        break;
      case 'slight right':
        instruction = 'Turn slightly right';
        break;
      case 'sharp left':
        instruction = 'Make a sharp left turn';
        break;
      case 'sharp right':
        instruction = 'Make a sharp right turn';
        break;
      case 'uturn':
        instruction = 'Make a U-turn';
        break;
      case 'straight':
        instruction = 'Continue straight';
        break;
      default:
        instruction = 'Take the $turnDirection';
    }

    return speak(formatNavigationStep(instruction, distance));
  }

  // Speak crossing alert
  Future<bool> speakCrossing(String crossingType, int? distance) {
    String instruction = 'Street crossing ahead';

    if (crossingType.toLowerCase().contains('traffic light')) {
      instruction = 'Traffic light crossing ahead';
    } else if (crossingType.toLowerCase().contains('zebra')) {
      instruction = 'Zebra crossing ahead';
    }

    return speak(formatNavigationStep(instruction, distance));
  }

  // Speak hazard warning
  Future<bool> speakHazard(String hazardType, int? distance) {
    String instruction = 'Caution, hazard ahead';

    switch (hazardType.toLowerCase()) {
      case 'construction':
        instruction = 'Caution, construction ahead';
        break;
      case 'obstacle':
        instruction = 'Caution, obstacle ahead';
        break;
      case 'pothole':
        instruction = 'Caution, pothole ahead';
        break;
      default:
        instruction = 'Caution, $hazardType ahead';
    }

    return speak(formatNavigationStep(instruction, distance));
  }

  // Speak destination reached
  Future<bool> speakDestinationReached(String destinationName) {
    return speak('You have reached your destination, $destinationName');
  }

  // Speak navigation status
  Future<bool> speakNavigationStatus(String status) {
    return speak(status);
  }

  // Dispose resources
  void dispose() {
    stop();
    _spokenTextController.close();
    _speakingStatusController.close();
  }
}
