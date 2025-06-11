import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../utils/vibration_pattern_tester.dart';
import '../widgets/device_info_card.dart';
import '../widgets/pattern_test_section.dart';
import '../widgets/comparison_test_section.dart';
import '../widgets/intensity_test_section.dart';

class VibrationTestScreen extends StatefulWidget {
  const VibrationTestScreen({super.key});

  @override
  State<VibrationTestScreen> createState() => _VibrationTestScreenState();
}

class _VibrationTestScreenState extends State<VibrationTestScreen> {
  final VibrationService _vibrationService = VibrationService();
  final VibrationPatternTester _patternTester = VibrationPatternTester();
  bool _supportsVibration = false;
  bool _supportsAmplitude = false;
  String _selectedPattern1 = 'onRoute';
  String _selectedPattern2 = 'approachingTurn';
  int _currentIntensity = VibrationService.mediumIntensity;

  @override
  void initState() {
    super.initState();
    _checkVibrationSupport();
  }

  Future<void> _checkVibrationSupport() async {
    final hasVibrator = await _vibrationService.hasVibrator();
    final hasAmplitudeControl = await _vibrationService.hasAmplitudeControl();

    setState(() {
      _supportsVibration = hasVibrator;
      _supportsAmplitude = hasAmplitudeControl;
    });
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
          : const Center(
              child: Text(
                'This device does not support vibration',
                style: TextStyle(fontSize: 18),
              ),
            ),
    );
  }
}
