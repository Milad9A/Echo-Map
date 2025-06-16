import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shake/shake.dart';

enum GestureType {
  shake,
  doubleTap,
  swipeDown,
  swipeUp,
  swipeLeft,
  swipeRight,
  longPress,
}

class GestureHandlerService {
  // Singleton pattern
  static final GestureHandlerService _instance =
      GestureHandlerService._internal();
  factory GestureHandlerService() => _instance;
  GestureHandlerService._internal();

  // Shake detector
  ShakeDetector? _shakeDetector;
  bool _isInitialized = false;

  // Stream controller for gesture events
  final StreamController<GestureType> _gestureController =
      StreamController<GestureType>.broadcast();

  // Public stream
  Stream<GestureType> get gestureStream => _gestureController.stream;

  // Initialize the gesture handler
  void initialize() {
    if (_isInitialized) return;

    try {
      // Initialize shake detection
      _shakeDetector = ShakeDetector.autoStart(
        onPhoneShake: (_) => {
          debugPrint('Shake detected'),
          _gestureController.add(GestureType.shake)
        },
        minimumShakeCount: 1,
        shakeSlopTimeMS: 500,
        shakeCountResetTime: 3000,
        shakeThresholdGravity: 2.7,
      );

      _isInitialized = true;
      debugPrint('GestureHandlerService initialized');
    } catch (e) {
      debugPrint('Error initializing gesture handler: $e');
    }
  }

  // Report a gesture event
  void triggerGesture(GestureType gesture) {
    _gestureController.add(gesture);
  }

  // Vibrate on gesture recognition for haptic feedback
  Future<void> vibrateFeedback({bool isLongFeedback = false}) async {
    try {
      if (isLongFeedback) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (e) {
      debugPrint('Failed to provide haptic feedback: $e');
    }
  }

  // Dispose of resources
  void dispose() {
    _shakeDetector?.stopListening();
    _shakeDetector = null;
    _gestureController.close();
    _isInitialized = false;
  }
}

// Widget extension for gesture handling
class AccessibleGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onLongPress;
  final VoidCallback? onTripleTap;
  final bool provideFeedback;

  const AccessibleGestureDetector({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.onSwipeDown,
    this.onLongPress,
    this.onTripleTap,
    this.provideFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap != null
          ? () {
              if (provideFeedback) HapticFeedback.selectionClick();
              onDoubleTap!();
              GestureHandlerService().triggerGesture(GestureType.doubleTap);
            }
          : null,
      onVerticalDragEnd: onSwipeDown != null
          ? (details) {
              if (details.velocity.pixelsPerSecond.dy > 200) {
                if (provideFeedback) HapticFeedback.mediumImpact();
                onSwipeDown!();
                GestureHandlerService().triggerGesture(GestureType.swipeDown);
              }
            }
          : null,
      onLongPress: onLongPress != null
          ? () {
              if (provideFeedback) HapticFeedback.heavyImpact();
              onLongPress!();
              GestureHandlerService().triggerGesture(GestureType.longPress);
            }
          : null,
      child: child,
    );
  }
}
