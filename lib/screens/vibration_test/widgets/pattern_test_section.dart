import 'package:flutter/material.dart';
import '../../../services/vibration_service.dart';

class PatternTestSection extends StatelessWidget {
  final VibrationService vibrationService;
  final int intensity;

  const PatternTestSection({
    super.key,
    required this.vibrationService,
    required this.intensity,
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
              'Test Individual Patterns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Current intensity: $intensity',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: VibrationService.patterns.keys.map((pattern) {
                return ElevatedButton(
                  onPressed: () {
                    // Debug print to verify intensity value
                    debugPrint(
                      'Playing pattern $pattern with intensity $intensity',
                    );
                    vibrationService.playPattern(pattern, intensity: intensity);
                  },
                  child: Text(pattern),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
