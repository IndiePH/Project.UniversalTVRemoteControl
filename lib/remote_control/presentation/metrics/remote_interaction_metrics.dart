/// Shared press-feedback timings for remote control interactions.
library;

import 'dart:ui' show Offset;

/// Scale applied while a remote control is actively pressed.
const double kRemotePressFeedbackScale = 0.94;

/// Duration for press-in and release scale transitions.
const Duration kRemotePressFeedbackDuration = Duration(milliseconds: 80);

/// Square [SizedBox] side length wrapping [RemotePressFeedback] in widget tests.
const double kRemotePressFeedbackTestChildSize = 80;

/// Tap/gesture origin at the center of [kRemotePressFeedbackTestChildSize].
const Offset kRemotePressFeedbackTestTapOffset = Offset(
  kRemotePressFeedbackTestChildSize / 2,
  kRemotePressFeedbackTestChildSize / 2,
);
