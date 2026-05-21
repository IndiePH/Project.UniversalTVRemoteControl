import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/presentation/interaction/remote_press_feedback.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_interaction_metrics.dart';

void main() {
  testWidgets('fires callback on pointer down for immediate response', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemotePressFeedback(
            onPressed: () => pressed = true,
            child: const SizedBox(
              width: kRemotePressFeedbackTestChildSize,
              height: kRemotePressFeedbackTestChildSize,
            ),
          ),
        ),
      ),
    );

    await tester.startGesture(kRemotePressFeedbackTestTapOffset);
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('does not fire callback when disabled', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemotePressFeedback(
            onPressed: () => pressed = true,
            enabled: false,
            child: const SizedBox(
              width: kRemotePressFeedbackTestChildSize,
              height: kRemotePressFeedbackTestChildSize,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(kRemotePressFeedbackTestTapOffset);
    await tester.pump();

    expect(pressed, isFalse);
  });

  testWidgets('uses shared press scale and duration while pressed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemotePressFeedback(
            onPressed: () {},
            child: const SizedBox(
              width: kRemotePressFeedbackTestChildSize,
              height: kRemotePressFeedbackTestChildSize,
            ),
          ),
        ),
      ),
    );

    await tester.startGesture(kRemotePressFeedbackTestTapOffset);
    await tester.pump();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, kRemotePressFeedbackScale);
    expect(scale.duration, kRemotePressFeedbackDuration);
  });
}
