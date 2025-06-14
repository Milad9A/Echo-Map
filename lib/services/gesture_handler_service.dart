import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shake/shake.dart';

enum GestureType { doubleTap, swipeDown, shake, longPress, tripleTap }

class GestureHandlerService {
  // Singleton pattern
  static final GestureHandlerService _instance =
      GestureHandlerService._internal();
  factory GestureHandlerService() => _instance;
  GestureHandlerService._internal();

  // Shake detector
  ShakeDetector? _shakeDetector;
  bool _isShakeDetectorActive = false;

  // Stream controller for gesture events
  final _gestureController = StreamController<GestureType>.broadcast();

  // Public stream
  Stream<GestureType> get gestureStream => _gestureController.stream;

  // Initialize the gesture handler
  void initialize() {
    // Initialize shake detector
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (event) {
        _gestureController.add(GestureType.shake);
      },
      minimumShakeCount: 2,
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
      shakeThresholdGravity: 2.7,
    );

    _isShakeDetectorActive = true;
  }

  // Report a gesture event
  void reportGesture(GestureType gesture) {
    _gestureController.add(gesture);
  }

  // Enable or disable shake detection
  void setShakeDetection(bool enabled) {
    if (enabled && !_isShakeDetectorActive) {
      _shakeDetector?.startListening();
      _isShakeDetectorActive = true;
    } else if (!enabled && _isShakeDetectorActive) {
      _shakeDetector?.stopListening();
      _isShakeDetectorActive = false;
    }
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
    _gestureController.close();
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
              GestureHandlerService().reportGesture(GestureType.doubleTap);
            }
          : null,
      onVerticalDragEnd: onSwipeDown != null
          ? (details) {
              if (details.velocity.pixelsPerSecond.dy > 200) {
                if (provideFeedback) HapticFeedback.mediumImpact();
                onSwipeDown!();
                GestureHandlerService().reportGesture(GestureType.swipeDown);
              }
            }
          : null,
      onLongPress: onLongPress != null
          ? () {
              if (provideFeedback) HapticFeedback.heavyImpact();
              onLongPress!();
              GestureHandlerService().reportGesture(GestureType.longPress);
            }
          : null,
      child: child,
    );
  }
}
