import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_interaction_metrics.dart';

/// Applies immediate scale feedback and optional haptic on press for remote controls.
///
/// The [onPressed] callback fires on pointer down so command dispatch feels instant
/// even when the transport round-trip is slower — unless [onHoldStart]/[onHoldEnd]
/// are also provided, in which case dispatch is deferred until the gesture resolves
/// as a tap or a hold (see [onHoldStart]'s doc for why). Callers that don't pass
/// them keep the eager-dispatch behavior above completely unchanged.
class RemotePressFeedback extends StatefulWidget {
  const RemotePressFeedback({
    super.key,
    required this.onPressed,
    required this.child,
    this.onPressHaptic,
    this.enabled = true,
    this.scale = kRemotePressFeedbackScale,
    this.onHoldStart,
    this.onHoldEnd,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final VoidCallback? onPressHaptic;
  final bool enabled;
  final double scale;

  /// Called once, when a press crosses the platform long-press threshold
  /// without releasing. When set (together with [onHoldEnd]), a plain tap
  /// and a hold become mutually exclusive for the same physical press:
  /// [onPressed] fires only for presses that release before the threshold;
  /// [onHoldStart]/[onHoldEnd] fire only for ones that don't. That
  /// exclusivity comes from Flutter's own gesture arena (a tap recognizer
  /// and a long-press recognizer on the same pointer resolve to exactly one
  /// winner) — not custom logic here.
  ///
  /// Why dispatch can't stay eager for these buttons: at pointer-down there
  /// is no way yet to know whether the user is about to tap or hold, so
  /// firing [onPressed] immediately (as non-hold-capable buttons do) would
  /// send a tap command and then also start a hold for the same press.
  final VoidCallback? onHoldStart;

  /// Called on release, exactly once per prior [onHoldStart] call. Also
  /// force-called by a watchdog timeout ([kRemoteHoldWatchdogTimeout]) or on
  /// dispose if the gesture's own end/cancel event is ever lost mid-hold
  /// (e.g. the app is backgrounded) — see
  /// `references/goals/goal-long-press-key.md` fact #19.
  final VoidCallback? onHoldEnd;

  @override
  State<RemotePressFeedback> createState() => _RemotePressFeedbackState();
}

class _RemotePressFeedbackState extends State<RemotePressFeedback> {
  bool _pressed = false;
  bool _holdActive = false;
  Timer? _holdWatchdog;

  bool get _interactive => widget.enabled && widget.onPressed != null;
  bool get _holdCapable =>
      widget.onHoldStart != null && widget.onHoldEnd != null;

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
    if (!_holdCapable) {
      widget.onPressed!.call();
    }
  }

  void _handleTapUp() {
    if (!_interactive) {
      return;
    }
    _setPressed(false);
    // The long-press recognizer winning the arena means onTapCancel fires
    // here, not onTapUp — this guard is defensive, not the primary path.
    if (_holdCapable && !_holdActive) {
      widget.onPressed!.call();
    }
  }

  void _handleTapCancel() {
    if (!_interactive) {
      return;
    }
    _setPressed(false);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (!_interactive || !_holdCapable) {
      return;
    }
    _holdActive = true;
    widget.onHoldStart!.call();
    _holdWatchdog?.cancel();
    _holdWatchdog = Timer(kRemoteHoldWatchdogTimeout, _endHoldIfActive);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _setPressed(false);
    _endHoldIfActive();
  }

  void _handleLongPressCancel() {
    _setPressed(false);
    _endHoldIfActive();
  }

  void _endHoldIfActive() {
    _holdWatchdog?.cancel();
    _holdWatchdog = null;
    if (!_holdActive) {
      return;
    }
    _holdActive = false;
    widget.onHoldEnd?.call();
  }

  @override
  void dispose() {
    _holdWatchdog?.cancel();
    if (_holdActive) {
      _holdActive = false;
      widget.onHoldEnd?.call();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_interactive) {
      return widget.child;
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (instance) {
                instance.onTapDown = _handleTapDown;
                instance.onTapUp = (_) => _handleTapUp();
                instance.onTapCancel = _handleTapCancel;
              },
            ),
        if (_holdCapable)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () =>
                    LongPressGestureRecognizer(duration: kRemoteHoldThreshold),
                (instance) {
                  instance.onLongPressStart = _handleLongPressStart;
                  instance.onLongPressEnd = _handleLongPressEnd;
                  instance.onLongPressCancel = _handleLongPressCancel;
                },
              ),
      },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: kRemotePressFeedbackDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
