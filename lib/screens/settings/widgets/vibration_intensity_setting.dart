import 'package:flutter/material.dart';
import '../../../services/vibration_service.dart';
import '../../../utils/theme_config.dart';

class VibrationIntensitySetting extends StatelessWidget {
  final int initialIntensity;
  final ValueChanged<double> onChanged;
  final VoidCallback onTest;

  const VibrationIntensitySetting({
    super.key,
    required this.initialIntensity,
    required this.onChanged,
    required this.onTest,
  });

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: ThemeConfig.smallPadding),
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Vibration Intensity',
                  style: TextStyle(
                    fontSize: ThemeConfig.mediumText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getIntensityLabel(initialIntensity),
                  style: const TextStyle(fontSize: ThemeConfig.mediumText),
                ),
              ],
            ),
            const SizedBox(height: ThemeConfig.standardPadding),
            Semantics(
              slider: true,
              value: _getIntensityLabel(initialIntensity),
              hint: 'Adjust vibration strength',
              child: Slider(
                value: initialIntensity.toDouble(),
                min: VibrationService.lowIntensity.toDouble(),
                max: VibrationService.highIntensity.toDouble(),
                divisions: 10,
                label: _getIntensityLabel(initialIntensity),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onChanged(VibrationService.lowIntensity.toDouble());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          initialIntensity == VibrationService.lowIntensity
                          ? ThemeConfig.accentColor
                          : null,
                    ),
                    child: const Text('Low'),
                  ),
                ),
                const SizedBox(width: ThemeConfig.smallPadding),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onChanged(VibrationService.mediumIntensity.toDouble());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          initialIntensity == VibrationService.mediumIntensity
                          ? ThemeConfig.accentColor
                          : null,
                    ),
                    child: const Text('Medium'),
                  ),
                ),
                const SizedBox(width: ThemeConfig.smallPadding),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onChanged(VibrationService.highIntensity.toDouble());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          initialIntensity == VibrationService.highIntensity
                          ? ThemeConfig.accentColor
                          : null,
                    ),
                    child: const Text('High'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThemeConfig.standardPadding),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.vibration),
                label: const Text('Test Vibration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.secondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
