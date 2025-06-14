import 'package:flutter/material.dart';
import '../../../utils/theme_config.dart';

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: ThemeConfig.standardPadding,
          horizontal: ThemeConfig.smallPadding,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: ThemeConfig.largeText,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.primaryColor,
          ),
        ),
      ),
    );
  }
}
