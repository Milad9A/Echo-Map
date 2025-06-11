import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import '../utils/vibration_pattern_tester.dart';

class ComparisonTestSection extends StatelessWidget {
  final VibrationPatternTester patternTester;
  final String selectedPattern1;
  final String selectedPattern2;
  final int intensity;
  final Function(String?) onPattern1Changed;
  final Function(String?) onPattern2Changed;

  const ComparisonTestSection({
    super.key,
    required this.patternTester,
    required this.selectedPattern1,
    required this.selectedPattern2,
    required this.intensity,
    required this.onPattern1Changed,
    required this.onPattern2Changed,
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
              'Compare Two Patterns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPattern1,
                    onChanged: onPattern1Changed,
                    items: VibrationService.patterns.keys
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                        .toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPattern2,
                    onChanged: onPattern2Changed,
                    items: VibrationService.patterns.keys
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => patternTester.comparePatterns(
                selectedPattern1,
                selectedPattern2,
                intensity: intensity,
              ),
              child: const Text('Compare Patterns'),
            ),
          ],
        ),
      ),
    );
  }
}
