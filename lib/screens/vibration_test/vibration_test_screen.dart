import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../services/vibration_service.dart';
import '../../utils/vibration_pattern_tester.dart';
import 'widgets/device_info_card.dart';
import 'widgets/comparison_test_section.dart';
import 'widgets/intensity_test_section.dart';
import 'widgets/pattern_test_section.dart';

class VibrationTestScreen extends StatefulWidget {
  const VibrationTestScreen({super.key});

  @override
  State<VibrationTestScreen> createState() => _VibrationTestScreenState();
}

class _VibrationTestScreenState extends State<VibrationTestScreen> {
  final VibrationService _vibrationService = VibrationService();
  final VibrationPatternTester _patternTester = VibrationPatternTester();
  final bool _isIOS = Platform.isIOS;
  final bool _isMobilePlatform = Platform.isIOS || Platform.isAndroid;
  bool _supportsVibration = false;
  bool _supportsAmplitude = false;
  bool _vibrationWorking = false;
  String _selectedPattern1 = 'onRoute';
  String _selectedPattern2 = 'approachingTurn';
  int _currentIntensity = VibrationService.mediumIntensity;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVibration();
  }

  Future<void> _initializeVibration() async {
    try {
      // Check if we're on a supported platform first
      if (!_isMobilePlatform) {
        setState(() {
          _errorMessage =
              'This platform may not support vibration functionality.';
        });
      }

      final hasVibrator = await _vibrationService.hasVibrator();
      final hasAmplitudeControl = await _vibrationService.hasAmplitudeControl();

      // Test if vibration actually works
      final vibrationTest = await _vibrationService.testVibration();

      setState(() {
        _supportsVibration = hasVibrator;
        _supportsAmplitude = hasAmplitudeControl;
        _vibrationWorking = vibrationTest;
        if (!_vibrationWorking && _errorMessage.isEmpty) {
          _errorMessage =
              'Vibration test failed. Check device settings and permissions.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing vibration: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibration Pattern Tester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () => _vibrationService.stopVibration(),
            tooltip: 'Stop Vibration',
          ),
        ],
      ),
      body: _supportsVibration
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeviceInfoCard(
                    supportsVibration: _supportsVibration,
                    supportsAmplitude: _supportsAmplitude,
                    vibrationWorking: _vibrationWorking,
                    errorMessage: _errorMessage,
                    isIOS: _isIOS,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await _vibrationService.testVibration();
                      setState(() {
                        _vibrationWorking = result;
                        _errorMessage = result
                            ? ''
                            : 'Vibration test failed. Check device settings.';
                      });
                    },
                    child: const Text('Test Vibration'),
                  ),
                  const SizedBox(height: 16),
                  PatternTestSection(
                    vibrationService: _vibrationService,
                    intensity: _currentIntensity,
                  ),
                  const SizedBox(height: 16),
                  ComparisonTestSection(
                    patternTester: _patternTester,
                    selectedPattern1: _selectedPattern1,
                    selectedPattern2: _selectedPattern2,
                    intensity: _currentIntensity,
                    onPattern1Changed: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPattern1 = newValue;
                        });
                      }
                    },
                    onPattern2Changed: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPattern2 = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  IntensityTestSection(
                    supportsAmplitude: _supportsAmplitude,
                    currentIntensity: _currentIntensity,
                    onIntensityChanged: (double value) {
                      setState(() {
                        _currentIntensity = value.round();
                      });
                    },
                    onLowPressed: () {
                      setState(() {
                        _currentIntensity = VibrationService.lowIntensity;
                      });
                    },
                    onMediumPressed: () {
                      setState(() {
                        _currentIntensity = VibrationService.mediumIntensity;
                      });
                    },
                    onHighPressed: () {
                      setState(() {
                        _currentIntensity = VibrationService.highIntensity;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _patternTester.testAllPatterns(),
                    child: const Text('Test All Patterns'),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'This device does not support vibration',
                    style: TextStyle(fontSize: 18),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _initializeVibration,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
    );
  }
}
