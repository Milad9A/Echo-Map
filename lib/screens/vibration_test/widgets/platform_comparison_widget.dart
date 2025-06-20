import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../../services/vibration_service.dart';
import '../../../utils/theme_config.dart';

class PlatformComparisonWidget extends StatefulWidget {
  const PlatformComparisonWidget({super.key});

  @override
  State<PlatformComparisonWidget> createState() =>
      _PlatformComparisonWidgetState();
}

class _PlatformComparisonWidgetState extends State<PlatformComparisonWidget> {
  final VibrationService _vibrationService = VibrationService();
  int _selectedIntensity = VibrationService.mediumIntensity;
  String _selectedPattern = 'onRoute';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform: ${Platform.isIOS ? "iOS" : "Android"}',
              style: const TextStyle(
                fontSize: ThemeConfig.largeText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.standardPadding),

            // Pattern selection
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
                  child: Text(value),
                );
              }).toList(),
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Intensity slider
            Text('Intensity: $_selectedIntensity'),
            Slider(
              value: _selectedIntensity.toDouble(),
              min: 50,
              max: 255,
              divisions: 8,
              onChanged: (double value) {
                setState(() {
                  _selectedIntensity = value.round();
                });
              },
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _vibrationService.playPattern(
                        _selectedPattern,
                        intensity: _selectedIntensity,
                      );
                    },
                    child: const Text('Test Pattern'),
                  ),
                ),
                const SizedBox(width: ThemeConfig.smallPadding),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _vibrationService.platformOptimizedVibrate(
                        duration: 500,
                        intensity: _selectedIntensity,
                      );
                    },
                    child: const Text('Platform Optimized'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Platform-specific info
            Container(
              padding: const EdgeInsets.all(ThemeConfig.standardPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Platform.isIOS ? 'iOS Optimizations:' : 'Android Features:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (Platform.isIOS) ...[
                    const Text('• Longer durations for better perception'),
                    const Text('• +20% intensity boost applied'),
                    const Text('• Fallback for amplitude control'),
                    const Text('• Pattern segmentation for long vibrations'),
                  ] else ...[
                    const Text('• Direct intensity mapping'),
                    const Text('• Native pattern support'),
                    const Text('• Full amplitude control available'),
                    const Text('• Precise timing control'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
