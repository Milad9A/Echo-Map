import 'package:flutter/material.dart';
import '../../../utils/theme_config.dart';

class SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: ThemeConfig.smallPadding),
        child: Padding(
          padding: const EdgeInsets.all(ThemeConfig.smallPadding),
          child: SwitchListTile(
            title: Text(
              title,
              style: const TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: ThemeConfig.smallText),
            ),
            value: value,
            onChanged: onChanged,
            activeColor: ThemeConfig.primaryColor,
          ),
        ),
      ),
    );
  }
}
