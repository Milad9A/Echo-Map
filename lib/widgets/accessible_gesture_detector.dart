import 'package:flutter/material.dart';

class AccessibleGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onTap;

  const AccessibleGestureDetector({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.onSwipeDown,
    this.onSwipeUp,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onPanEnd: (details) {
        // Handle swipe gestures
        final velocity = details.velocity.pixelsPerSecond;

        // Minimum velocity threshold for swipe detection
        if (velocity.distance < 500) return;

        if (details.velocity.pixelsPerSecond.dx.abs() >
            details.velocity.pixelsPerSecond.dy.abs()) {
          // Horizontal swipe
          if (details.velocity.pixelsPerSecond.dx > 0) {
            onSwipeRight?.call();
          } else {
            onSwipeLeft?.call();
          }
        } else {
          // Vertical swipe
          if (details.velocity.pixelsPerSecond.dy > 0) {
            onSwipeDown?.call();
          } else {
            onSwipeUp?.call();
          }
        }
      },
      child: Semantics(
        container: true,
        child: child,
      ),
    );
  }
}
