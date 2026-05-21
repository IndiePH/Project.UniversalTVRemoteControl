import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_interaction_metrics.dart';

/// Applies immediate scale feedback and optional haptic on press for remote controls.
///
/// The [onPressed] callback fires on pointer down so command dispatch feels instant
/// even when the transport round-trip is slower.
class RemotePressFeedback extends StatefulWidget {
  const RemotePressFeedback({
    super.key,
    required this.onPressed,
    required this.child,
    this.onPressHaptic,
    this.enabled = true,
    this.scale = kRemotePressFeedbackScale,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final VoidCallback? onPressHaptic;
  final bool enabled;
  final double scale;

  @override
  State<RemotePressFeedback> createState() => _RemotePressFeedbackState();
}

class _RemotePressFeedbackState extends State<RemotePressFeedback> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_interactive) {
      return;
    }
    _setPressed(true);
    widget.onPressHaptic?.call();
    widget.onPressed!.call();
  }

  void _handleTapEnd() {
    if (!_interactive) {
      return;
    }
    _setPressed(false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_interactive) {
      return widget.child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: (_) => _handleTapEnd(),
      onTapCancel: _handleTapEnd,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: kRemotePressFeedbackDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
