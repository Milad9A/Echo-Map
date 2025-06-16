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
              'Test Vibration Patterns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Each pattern has a unique vibration to help you distinguish different navigation events:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Grid of pattern test buttons
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3,
              children: VibrationService.patterns.keys.map((patternName) {
                return ElevatedButton(
                  onPressed: () {
                    vibrationService.playPattern(patternName,
                        intensity: intensity);
                  },
                  child: Text(
                    _getPatternDisplayName(patternName),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Description of patterns
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildPatternDescription(
                    'onRoute', 'Light pulse when walking correctly'),
                _buildPatternDescription(
                    'approachingTurn', 'Double pulse before turns'),
                _buildPatternDescription('leftTurn', 'Pattern for left turns'),
                _buildPatternDescription(
                    'rightTurn', 'Pattern for right turns'),
                _buildPatternDescription(
                    'wrongDirection', 'Strong pulse when off-route'),
                _buildPatternDescription(
                    'destinationReached', 'Triple pulse at destination'),
                _buildPatternDescription(
                    'crossingStreet', 'Warning for street crossings'),
                _buildPatternDescription(
                    'hazardWarning', 'Alert for nearby hazards'),
              ],
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
        return 'Street Crossing';
      case 'hazardWarning':
        return 'Hazard Warning';
      default:
        return patternName;
    }
  }

  Widget _buildPatternDescription(String pattern, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getPatternDisplayName(pattern),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              description,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
