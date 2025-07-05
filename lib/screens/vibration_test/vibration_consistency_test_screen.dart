import 'package:flutter/material.dart';
import '../../services/vibration_service.dart';

class VibrationConsistencyTestScreen extends StatefulWidget {
  const VibrationConsistencyTestScreen({super.key});

  @override
  State<VibrationConsistencyTestScreen> createState() =>
      _VibrationConsistencyTestScreenState();
}

class _VibrationConsistencyTestScreenState
    extends State<VibrationConsistencyTestScreen> {
  final VibrationService _vibrationService = VibrationService();
  bool _isTestingRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibration Consistency Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Platform Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getPlatformInfo(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final info = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Platform: ${info['platform']}'),
                              Text(
                                  'Intensity Calibration: ${info['intensityCalibration']}'),
                              Text(
                                  'Pattern Optimization: ${info['patternOptimization']}'),
                              Text(
                                  'Long Vibration Handling: ${info['longVibrationHandling']}'),
                            ],
                          );
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Capabilities',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, bool>>(
                      future: _vibrationService.getDeviceCapabilities(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final capabilities = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Has Vibrator: ${capabilities['hasVibrator']}'),
                              Text(
                                  'Has Amplitude Control: ${capabilities['hasAmplitudeControl']}'),
                              Text(
                                  'Platform Optimized: ${capabilities['isPlatformOptimized']}'),
                              Text(
                                  'Supports Patterns: ${capabilities['supportsPatterns']}'),
                            ],
                          );
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Test Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _isTestingRunning ? null : () => _testIntensityLevels(),
              child: const Text('Test Intensity Levels'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTestingRunning ? null : () => _testKeyPatterns(),
              child: const Text('Test Key Navigation Patterns'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  _isTestingRunning ? null : () => _testCrossPlatformFeel(),
              child: const Text('Test Cross-Platform Feel'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  _isTestingRunning ? null : () => _testPlatformConsistency(),
              child: const Text('Full Platform Consistency Test'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Individual Pattern Tests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _buildPatternButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPatternButtons() {
    final patterns = [
      'onRoute',
      'approachingTurn',
      'leftTurn',
      'rightTurn',
      'wrongDirection',
      'destinationReached',
      'crossingStreet',
      'hazardWarning',
    ];

    return patterns.map((pattern) {
      return ElevatedButton(
        onPressed: _isTestingRunning ? null : () => _testPattern(pattern),
        child: Text(
          pattern,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }).toList();
  }

  Future<Map<String, dynamic>> _getPlatformInfo() async {
    return _vibrationService.getPlatformInfo();
  }

  Future<void> _testIntensityLevels() async {
    setState(() => _isTestingRunning = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing Low Intensity...')),
      );
      await _vibrationService.adaptiveVibrate(
          duration: 400, intensity: VibrationService.lowIntensity);
      await Future.delayed(const Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing Medium Intensity...')),
      );
      await _vibrationService.adaptiveVibrate(
          duration: 400, intensity: VibrationService.mediumIntensity);
      await Future.delayed(const Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing High Intensity...')),
      );
      await _vibrationService.adaptiveVibrate(
          duration: 400, intensity: VibrationService.highIntensity);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intensity test completed')),
      );
    } finally {
      setState(() => _isTestingRunning = false);
    }
  }

  Future<void> _testKeyPatterns() async {
    setState(() => _isTestingRunning = true);

    try {
      final keyPatterns = [
        'onRoute',
        'leftTurn',
        'rightTurn',
        'wrongDirection'
      ];

      for (final pattern in keyPatterns) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Testing $pattern...')),
        );
        await _vibrationService.playPattern(pattern);
        await Future.delayed(const Duration(seconds: 2));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key patterns test completed')),
      );
    } finally {
      setState(() => _isTestingRunning = false);
    }
  }

  Future<void> _testCrossPlatformFeel() async {
    setState(() => _isTestingRunning = true);

    try {
      await _vibrationService.testCrossPlatformFeel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cross-platform feel test completed')),
      );
    } finally {
      setState(() => _isTestingRunning = false);
    }
  }

  Future<void> _testPlatformConsistency() async {
    setState(() => _isTestingRunning = true);

    try {
      await _vibrationService.testPlatformConsistency();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Platform consistency test completed')),
      );
    } finally {
      setState(() => _isTestingRunning = false);
    }
  }

  Future<void> _testPattern(String pattern) async {
    setState(() => _isTestingRunning = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Testing $pattern pattern...')),
      );
      await _vibrationService.playPattern(pattern);
    } finally {
      setState(() => _isTestingRunning = false);
    }
  }
}
