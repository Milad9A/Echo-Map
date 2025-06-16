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
              'Test Navigation Patterns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap each button to experience different navigation vibration patterns:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Grid of pattern buttons
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: VibrationService.patterns.keys.map((patternName) {
                return ElevatedButton(
                  onPressed: () => vibrationService.playPattern(
                    patternName,
                    intensity: intensity,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    _getPatternDisplayName(patternName),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Pattern descriptions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pattern Guide:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...VibrationService.patterns.keys.map((pattern) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${_getPatternDisplayName(pattern)}: ${_getPatternDescription(pattern)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
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

  String _getPatternDescription(String patternName) {
    switch (patternName) {
      case 'onRoute':
        return 'Gentle confirmation you\'re on the right path';
      case 'approachingTurn':
        return 'Alerts you that a turn is coming up';
      case 'leftTurn':
        return 'Indicates a left turn';
      case 'rightTurn':
        return 'Indicates a right turn';
      case 'wrongDirection':
        return 'Strong warning that you\'ve gone off route';
      case 'destinationReached':
        return 'Celebration pattern when you arrive';
      case 'crossingStreet':
        return 'Alert for street crossings';
      case 'hazardWarning':
        return 'Warning for obstacles or hazards';
      default:
        return 'Navigation feedback pattern';
    }
  }
}
