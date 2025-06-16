import 'package:flutter/material.dart';
import '../../../services/vibration_service.dart';

class IntensityTestSection extends StatelessWidget {
  final bool supportsAmplitude;
  final int currentIntensity;
  final Function(double) onIntensityChanged;
  final VoidCallback onLowPressed;
  final VoidCallback onMediumPressed;
  final VoidCallback onHighPressed;

  const IntensityTestSection({
    super.key,
    required this.supportsAmplitude,
    required this.currentIntensity,
    required this.onIntensityChanged,
    required this.onLowPressed,
    required this.onMediumPressed,
    required this.onHighPressed,
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Intensity Levels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Slider(
              value: currentIntensity.toDouble(),
              min: 1,
              max: 255,
              divisions: 10,
              label: _getIntensityLabel(currentIntensity),
              onChanged: supportsAmplitude ? onIntensityChanged : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Intensity:'),
                Text(
                  '${currentIntensity.toString()} (${_getIntensityLabel(currentIntensity)})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (!supportsAmplitude)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'This device does not support amplitude control. Fixed intensity will be used.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: onLowPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentIntensity == VibrationService.lowIntensity
                            ? Colors.lightBlue
                            : null,
                  ),
                  child: const Text('Low'),
                ),
                ElevatedButton(
                  onPressed: onMediumPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentIntensity == VibrationService.mediumIntensity
                            ? Colors.lightBlue
                            : null,
                  ),
                  child: const Text('Medium'),
                ),
                ElevatedButton(
                  onPressed: onHighPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentIntensity == VibrationService.highIntensity
                            ? Colors.lightBlue
                            : null,
                  ),
                  child: const Text('High'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
