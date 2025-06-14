import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceCommandStatus { idle, listening, processing, error }

class VoiceCommandService {
  // Singleton pattern
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  // Speech recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  VoiceCommandStatus _status = VoiceCommandStatus.idle;

  // Command mapping
  final Map<String, List<String>> _commandPatterns = {
    'navigate': ['navigate to', 'go to', 'take me to', 'directions to'],
    'startNavigation': ['start navigation', 'begin navigation', 'start'],
    'stopNavigation': ['stop navigation', 'end navigation', 'cancel', 'stop'],
    'currentLocation': ['where am i', 'my location', 'current location'],
    'repeatInstruction': ['repeat', 'repeat that', 'say again'],
    'settings': ['settings', 'open settings', 'change settings'],
    'help': ['help', 'i need help', 'assistance'],
  };

  // Stream controllers
  final _commandController =
      StreamController<CommandRecognitionResult>.broadcast();
  final _statusController = StreamController<VoiceCommandStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Public streams
  Stream<CommandRecognitionResult> get commandStream =>
      _commandController.stream;
  Stream<VoiceCommandStatus> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Status getter
  VoiceCommandStatus get status => _status;

  // Initialize the speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) => _handleError("Speech recognition error: $error"),
        onStatus: (status) => _handleSpeechStatus(status),
      );

      return _isInitialized;
    } catch (e) {
      _handleError("Failed to initialize speech recognition: $e");
      return false;
    }
  }

  // Start listening for voice commands
  Future<bool> startListening({
    Duration? listenFor,
    double pauseFor = 2.0,
    String localeId = 'en_US',
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      _updateStatus(VoiceCommandStatus.listening);

      return await _speech.listen(
        onResult: _processRecognitionResult,
        listenFor: listenFor,
        pauseFor: Duration(seconds: pauseFor.toInt()),
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      _handleError("Failed to start speech recognition: $e");
      _updateStatus(VoiceCommandStatus.error);
      return false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      _updateStatus(VoiceCommandStatus.idle);
    }
  }

  // Process speech recognition results
  void _processRecognitionResult(SpeechRecognitionResult result) {
    // Skip processing if the result is empty
    if (result.recognizedWords.isEmpty) return;

    // Convert to lowercase for better matching
    final String transcript = result.recognizedWords.toLowerCase();

    // Only process final results (unless we want to show partial results in the UI)
    if (result.finalResult) {
      _updateStatus(VoiceCommandStatus.processing);

      // Try to match the transcript to a command
      final CommandRecognitionResult? commandResult = _matchCommandPattern(
        transcript,
      );

      if (commandResult != null) {
        _commandController.add(commandResult);
      } else if (transcript.isNotEmpty) {
        // If no command matched but we have text, report as unknown command
        _commandController.add(
          CommandRecognitionResult(
            command: 'unknown',
            transcript: transcript,
            confidence: result.confidence,
          ),
        );
      }

      _updateStatus(VoiceCommandStatus.idle);
    }
  }

  // Match transcript to command patterns
  CommandRecognitionResult? _matchCommandPattern(String transcript) {
    String? matchedCommand;
    String matchedPattern = '';
    double confidence = 0.0;

    // Check each command and its patterns
    for (final entry in _commandPatterns.entries) {
      final command = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        if (transcript.contains(pattern)) {
          // If this pattern is longer than previous matches, it's likely more specific
          if (pattern.length > matchedPattern.length) {
            matchedCommand = command;
            matchedPattern = pattern;
            // Calculate a simple confidence score based on the ratio of pattern length to transcript length
            confidence = pattern.length / transcript.length;
          }
        }
      }
    }

    // If we found a match, create a result
    if (matchedCommand != null) {
      return CommandRecognitionResult(
        command: matchedCommand,
        transcript: transcript,
        confidence: confidence,
        parameters: _extractParameters(
          matchedCommand,
          matchedPattern,
          transcript,
        ),
      );
    }

    return null;
  }

  // Extract parameters from the command
  Map<String, String>? _extractParameters(
    String command,
    String pattern,
    String transcript,
  ) {
    // Simple parameter extraction - everything after the pattern
    if (command == 'navigate') {
      final index = transcript.indexOf(pattern);
      if (index >= 0) {
        final destination = transcript.substring(index + pattern.length).trim();
        if (destination.isNotEmpty) {
          return {'destination': destination};
        }
      }
    }

    // Add more parameter extraction logic for other commands as needed

    return null;
  }

  // Handle speech recognition status updates
  void _handleSpeechStatus(String status) {
    debugPrint('Speech recognition status: $status');

    if (status == 'listening') {
      _updateStatus(VoiceCommandStatus.listening);
    } else if (status == 'done') {
      _updateStatus(VoiceCommandStatus.idle);
    }
  }

  // Handle errors
  void _handleError(String message) {
    debugPrint('Voice command error: $message');
    _errorController.add(message);
    _updateStatus(VoiceCommandStatus.error);
  }

  // Update status and notify listeners
  void _updateStatus(VoiceCommandStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  // Check if speech recognition is available
  Future<bool> isAvailable() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }

  // Get available locales
  Future<List<dynamic>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speech.locales();
  }

  // Dispose of resources
  void dispose() {
    stopListening();
    _commandController.close();
    _statusController.close();
    _errorController.close();
  }
}

// Class to represent a recognized command
class CommandRecognitionResult {
  final String command;
  final String transcript;
  final double confidence;
  final Map<String, String>? parameters;

  CommandRecognitionResult({
    required this.command,
    required this.transcript,
    this.confidence = 0.0,
    this.parameters,
  });

  @override
  String toString() =>
      'Command: $command, Transcript: $transcript, Confidence: $confidence, Parameters: $parameters';
}
