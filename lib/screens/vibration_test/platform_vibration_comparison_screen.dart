import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../services/vibration_service.dart';
import '../../utils/theme_config.dart';

class PlatformVibrationComparisonScreen extends StatefulWidget {
  const PlatformVibrationComparisonScreen({super.key});

  @override
  State<PlatformVibrationComparisonScreen> createState() =>
      _PlatformVibrationComparisonScreenState();
}

class _PlatformVibrationComparisonScreenState
    extends State<PlatformVibrationComparisonScreen> {
  final VibrationService _vibrationService = VibrationService();
  int _currentIntensity = VibrationService.mediumIntensity;
  String _selectedPattern = 'onRoute';
  bool _isRunningTest = false;

  String get _platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return 'Unknown';
  }

  Color get _platformColor {
    if (Platform.isIOS) return Colors.blue;
    if (Platform.isAndroid) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Platform Vibration Comparison ($_platformName)'),
        backgroundColor: _platformColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform info card
            _buildPlatformInfoCard(),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Pattern selection
            _buildPatternSelector(),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Intensity control
            _buildIntensityControl(),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Test buttons
            _buildTestButtons(),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Platform comparison table
            _buildPlatformComparisonTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformInfoCard() {
    final platformInfo = _vibrationService.getPlatformInfo();

    return Card(
      color: _platformColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Platform: $_platformName',
              style: const TextStyle(
                fontSize: ThemeConfig.largeText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            ...platformInfo.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(fontSize: ThemeConfig.smallText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Pattern',
              style: TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            DropdownButton<String>(
              value: _selectedPattern,
              isExpanded: true,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPattern = newValue;
                  });
                }
              },
              items: VibrationService.patterns.keys
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(_getPatternDisplayName(value)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intensity: $_currentIntensity (${_getIntensityLabel(_currentIntensity)})',
              style: const TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            Slider(
              value: _currentIntensity.toDouble(),
              min: VibrationService.lowIntensity.toDouble(),
              max: VibrationService.highIntensity.toDouble(),
              divisions: 10,
              label: _getIntensityLabel(_currentIntensity),
              onChanged: (double value) {
                setState(() {
                  _currentIntensity = value.round();
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIntensity = VibrationService.lowIntensity;
                    });
                  },
                  child: const Text('Low'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIntensity = VibrationService.mediumIntensity;
                    });
                  },
                  child: const Text('Medium'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIntensity = VibrationService.highIntensity;
                    });
                  },
                  child: const Text('High'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Vibrations',
              style: TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            ElevatedButton(
              onPressed: _isRunningTest ? null : () => _testSelectedPattern(),
              child:
                  Text(_isRunningTest ? 'Testing...' : 'Test Selected Pattern'),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            ElevatedButton(
              onPressed: _isRunningTest ? null : () => _testPlatformOptimized(),
              child: Text(
                  _isRunningTest ? 'Testing...' : 'Test Platform Optimized'),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            ElevatedButton(
              onPressed: _isRunningTest ? null : () => _testAllPatterns(),
              child: Text(_isRunningTest ? 'Testing...' : 'Test All Patterns'),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            ElevatedButton(
              onPressed:
                  _isRunningTest ? null : () => _testPlatformConsistency(),
              child: Text(
                  _isRunningTest ? 'Testing...' : 'Test Platform Consistency'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformComparisonTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Comparison',
              style: TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            Table(
              border: TableBorder.all(),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Colors.grey),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Feature',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('iOS',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Android',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                _buildTableRow('Intensity Boost', '1.3x (min 80)', '1.1x'),
                _buildTableRow('Pattern Timing', 'Shorter + longer pauses',
                    'Standard timing'),
                _buildTableRow(
                    'Long Vibrations', 'Segmented (800ms max)', 'Direct'),
                _buildTableRow('Amplitude Control', 'Limited', 'Full'),
                _buildTableRow(
                    'Haptic Feedback', 'Core Haptics', 'Motor-based'),
                _buildTableRow(
                    'Pattern Clarity', 'Optimized pauses', 'Standard'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(
      String feature, String iosValue, String androidValue) {
    final isCurrentPlatform = Platform.isIOS;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(feature),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            iosValue,
            style: TextStyle(
              fontWeight:
                  isCurrentPlatform ? FontWeight.bold : FontWeight.normal,
              color: isCurrentPlatform ? Colors.blue : Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            androidValue,
            style: TextStyle(
              fontWeight:
                  !isCurrentPlatform ? FontWeight.bold : FontWeight.normal,
              color: !isCurrentPlatform ? Colors.green : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  String _getPatternDisplayName(String patternName) {
    switch (patternName) {
      case 'onRoute':
        return 'On Route';
      case 'approachingTurn':
        return 'Approaching Turn';
      case 'leftTurn':
        return 'Left Turn';
      case 'rightTurn':
        return 'Right Turn';
      case 'wrongDirection':
        return 'Wrong Direction';
      case 'destinationReached':
        return 'Destination Reached';
      case 'crossingStreet':
        return 'Crossing Street';
      case 'hazardWarning':
        return 'Hazard Warning';
      default:
        return patternName;
    }
  }

  String _getIntensityLabel(int value) {
    if (value <= VibrationService.lowIntensity + 10) {
      return 'Low';
    } else if (value >= VibrationService.highIntensity - 10) {
      return 'High';
    } else if (value >= VibrationService.mediumIntensity - 10 &&
        value <= VibrationService.mediumIntensity + 10) {
      return 'Medium';
    } else if (value < VibrationService.mediumIntensity) {
      return 'Low-Medium';
    } else {
      return 'Medium-High';
    }
  }

  Future<void> _testSelectedPattern() async {
    setState(() {
      _isRunningTest = true;
    });

    try {
      await _vibrationService.playPattern(_selectedPattern,
          intensity: _currentIntensity);
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  Future<void> _testPlatformOptimized() async {
    setState(() {
      _isRunningTest = true;
    });

    try {
      await _vibrationService.platformOptimizedVibrate(
        duration: 500,
        intensity: _currentIntensity,
      );
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  Future<void> _testAllPatterns() async {
    setState(() {
      _isRunningTest = true;
    });

    try {
      await _vibrationService.testAllPatterns(intensity: _currentIntensity);
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  Future<void> _testPlatformConsistency() async {
    setState(() {
      _isRunningTest = true;
    });

    try {
      await _vibrationService.testPlatformConsistency(
          intensity: _currentIntensity);
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }
}
