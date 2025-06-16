import 'package:flutter/material.dart';
import '../../../utils/theme_config.dart';

class ThemeSelector extends StatelessWidget {
  final ThemeMode currentTheme;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeSelector({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: ThemeConfig.smallPadding),
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Theme',
              style: TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.standardPadding),

            // Light Theme Option
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              subtitle: const Text('Use light colors'),
              value: ThemeMode.light,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  onThemeChanged(value);
                }
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Dark Theme Option
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              subtitle: const Text('Use dark colors'),
              value: ThemeMode.dark,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  onThemeChanged(value);
                }
              },
              contentPadding: EdgeInsets.zero,
            ),

            // System Theme Option
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              subtitle: const Text('Match device settings'),
              value: ThemeMode.system,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  onThemeChanged(value);
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
