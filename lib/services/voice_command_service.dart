import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceCommandStatus {
  idle,
  listening,
  processing,
  error,
}

class CommandRecognitionResult {
  final String command;
  final String transcript;
  final Map<String, dynamic>? parameters;

  CommandRecognitionResult({
    required this.command,
    required this.transcript,
    this.parameters,
  });
}

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final StreamController<VoiceCommandStatus> _statusController =
      StreamController<VoiceCommandStatus>.broadcast();
  final StreamController<CommandRecognitionResult> _commandController =
      StreamController<CommandRecognitionResult>.broadcast();

  VoiceCommandStatus _currentStatus = VoiceCommandStatus.idle;
  late stt.SpeechToText _speechToText;
  bool _isInitialized = false;

  Stream<VoiceCommandStatus> get statusStream => _statusController.stream;
  Stream<CommandRecognitionResult> get commandStream =>
      _commandController.stream;

  Future<bool> isAvailable() async {
    try {
      if (!_isInitialized) {
        _speechToText = stt.SpeechToText();
        _isInitialized = await _speechToText.initialize(
          onError: (error) {
            debugPrint('Speech recognition error: $error');
            _updateStatus(VoiceCommandStatus.error);
          },
          onStatus: (status) {
            debugPrint('Speech recognition status: $status');
            if (status == 'listening') {
              _updateStatus(VoiceCommandStatus.listening);
            } else if (status == 'notListening') {
              _updateStatus(VoiceCommandStatus.idle);
            }
          },
        );
      }
      return _isInitialized && _speechToText.isAvailable;
    } catch (e) {
      debugPrint('Error checking voice command availability: $e');
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized || !_speechToText.isAvailable) {
      debugPrint('Speech recognition not available');
      return;
    }

    if (_speechToText.isListening) {
      debugPrint('Already listening');
      return;
    }

    try {
      _updateStatus(VoiceCommandStatus.listening);

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            _updateStatus(VoiceCommandStatus.processing);
            _processVoiceInput(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 2),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
        ),
      );
    } catch (e) {
      debugPrint('Error starting voice recognition: $e');
      _updateStatus(VoiceCommandStatus.error);
    }
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    _updateStatus(VoiceCommandStatus.idle);
  }

  void _processVoiceInput(String transcript) {
    debugPrint('Processing voice input: $transcript');

    final lowerTranscript = transcript.toLowerCase().trim();

    // Simple command matching
    String command = 'unknown';
    Map<String, dynamic>? parameters;

    if (lowerTranscript.contains('navigate') ||
        lowerTranscript.contains('navigation')) {
      command = 'navigate';
      // Extract destination if mentioned
      if (lowerTranscript.contains(' to ')) {
        final parts = lowerTranscript.split(' to ');
        if (parts.length > 1) {
          parameters = {'destination': parts[1].trim()};
        }
      }
    } else if (lowerTranscript.contains('start navigation') ||
        lowerTranscript.contains('begin navigation')) {
      command = 'startNavigation';
    } else if (lowerTranscript.contains('stop') ||
        lowerTranscript.contains('cancel')) {
      command = 'stop';
    } else if (lowerTranscript.contains('settings') ||
        lowerTranscript.contains('setting')) {
      command = 'settings';
    } else if (lowerTranscript.contains('help')) {
      command = 'help';
    }

    final result = CommandRecognitionResult(
      command: command,
      transcript: transcript,
      parameters: parameters,
    );

    _commandController.add(result);
    _updateStatus(VoiceCommandStatus.idle);
  }

  void _updateStatus(VoiceCommandStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }
}
