/// Shared gesture and scroll constants for Flutter widget tests.
library;

import 'dart:ui' show Offset;

/// Horizontal drag that triggers [Dismissible] swipe-to-remove in tests.
const Offset kRemoteWidgetTestSwipeToDismissOffset = Offset(-500, 0);

/// [WidgetTester.scrollUntilVisible] delta for long settings / debug sheets.
const double kRemoteWidgetTestScrollUntilVisibleDelta = 150;

/// Tap outside sheet content to dismiss modal barriers in tests.
const Offset kRemoteWidgetTestDismissBarrierTapOffset = Offset(20, 20);
