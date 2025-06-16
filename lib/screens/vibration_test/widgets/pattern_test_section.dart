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

            // Navigation patterns
            _buildPatternButton(
              'On Route',
              'Gentle feedback when staying on course',
              () => vibrationService.onRouteFeedback(intensity: intensity),
            ),
            _buildPatternButton(
              'Approaching Turn',
              'Alert when a turn is coming up',
              () => vibrationService.approachingTurnFeedback(
                  intensity: intensity),
            ),
            _buildPatternButton(
              'Left Turn',
              'Pattern for left turn instruction',
              () => vibrationService.leftTurnFeedback(intensity: intensity),
            ),
            _buildPatternButton(
              'Right Turn',
              'Pattern for right turn instruction',
              () => vibrationService.rightTurnFeedback(intensity: intensity),
            ),
            _buildPatternButton(
              'Wrong Direction',
              'Strong alert when going off route',
              () =>
                  vibrationService.wrongDirectionFeedback(intensity: intensity),
            ),
            _buildPatternButton(
              'Destination Reached',
              'Celebration pattern when arriving',
              () => vibrationService.destinationReachedFeedback(
                  intensity: intensity),
            ),
            _buildPatternButton(
              'Street Crossing',
              'Warning when approaching a street crossing',
              () =>
                  vibrationService.crossingStreetFeedback(intensity: intensity),
            ),
            _buildPatternButton(
              'Hazard Warning',
              'Alert for obstacles or hazards',
              () =>
                  vibrationService.hazardWarningFeedback(intensity: intensity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternButton(
      String title, String description, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
