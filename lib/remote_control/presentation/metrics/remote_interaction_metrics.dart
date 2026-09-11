/// Shared press-feedback timings for remote control interactions.
library;

import 'dart:ui' show Offset;

/// Scale applied while a remote control is actively pressed.
const double kRemotePressFeedbackScale = 0.94;

/// Duration for press-in and release scale transitions.
const Duration kRemotePressFeedbackDuration = Duration(milliseconds: 80);

/// How long a press must be held before it's recognized as a hold gesture
/// rather than a tap — matches the platform's standard long-press threshold
/// (`kLongPressTimeout` in Flutter's gestures library).
const Duration kRemoteHoldThreshold = Duration(milliseconds: 500);

/// Hard ceiling on a single hold: force-releases (sends the `up` phase) if
/// the gesture's own end event is ever lost — e.g. the app is backgrounded
/// mid-hold. Generous enough that no legitimate hold hits it; see
/// `references/goals/goal-long-press-key.md` fact #19 (Roku's confirmed
/// stuck-key risk, defended against the same way here for every brand).
const Duration kRemoteHoldWatchdogTimeout = Duration(seconds: 60);

/// Square [SizedBox] side length wrapping [RemotePressFeedback] in widget tests.
const double kRemotePressFeedbackTestChildSize = 80;

/// Tap/gesture origin at the center of [kRemotePressFeedbackTestChildSize].
const Offset kRemotePressFeedbackTestTapOffset = Offset(
  kRemotePressFeedbackTestChildSize / 2,
  kRemotePressFeedbackTestChildSize / 2,
);
