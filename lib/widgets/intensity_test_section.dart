import 'package:flutter/material.dart';

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
              label: currentIntensity.toString(),
              onChanged: supportsAmplitude ? onIntensityChanged : null,
            ),
            Text('Current Intensity: $currentIntensity'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: onLowPressed,
                  child: const Text('Low'),
                ),
                ElevatedButton(
                  onPressed: onMediumPressed,
                  child: const Text('Medium'),
                ),
                ElevatedButton(
                  onPressed: onHighPressed,
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
