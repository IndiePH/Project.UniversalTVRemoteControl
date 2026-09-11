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

  group('hold gesture (onHoldStart/onHoldEnd set)', () {
    testWidgets('a quick release fires onPressed, not onHoldStart/onHoldEnd', (
      tester,
    ) async {
      var pressed = false;
      var holdStarted = false;
      var holdEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePressFeedback(
              onPressed: () => pressed = true,
              onHoldStart: () => holdStarted = true,
              onHoldEnd: () => holdEnded = true,
              child: const SizedBox(
                width: kRemotePressFeedbackTestChildSize,
                height: kRemotePressFeedbackTestChildSize,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        kRemotePressFeedbackTestTapOffset,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();

      expect(pressed, isTrue);
      expect(holdStarted, isFalse);
      expect(holdEnded, isFalse);
    });

    testWidgets(
      'onPressed does not fire eagerly on pointer-down when hold callbacks are set',
      (tester) async {
        var pressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RemotePressFeedback(
                onPressed: () => pressed = true,
                onHoldStart: () {},
                onHoldEnd: () {},
                child: const SizedBox(
                  width: kRemotePressFeedbackTestChildSize,
                  height: kRemotePressFeedbackTestChildSize,
                ),
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          kRemotePressFeedbackTestTapOffset,
        );
        await tester.pump();

        expect(pressed, isFalse);

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets('holding past the threshold fires onHoldStart, not onPressed', (
      tester,
    ) async {
      var pressed = false;
      var holdStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePressFeedback(
              onPressed: () => pressed = true,
              onHoldStart: () => holdStarted = true,
              onHoldEnd: () {},
              child: const SizedBox(
                width: kRemotePressFeedbackTestChildSize,
                height: kRemotePressFeedbackTestChildSize,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        kRemotePressFeedbackTestTapOffset,
      );
      await tester.pump(
        kRemoteHoldThreshold + const Duration(milliseconds: 50),
      );

      expect(holdStarted, isTrue);
      expect(pressed, isFalse);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('releasing after a hold fires onHoldEnd exactly once', (
      tester,
    ) async {
      var holdEndedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePressFeedback(
              onPressed: () {},
              onHoldStart: () {},
              onHoldEnd: () => holdEndedCount++,
              child: const SizedBox(
                width: kRemotePressFeedbackTestChildSize,
                height: kRemotePressFeedbackTestChildSize,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        kRemotePressFeedbackTestTapOffset,
      );
      await tester.pump(
        kRemoteHoldThreshold + const Duration(milliseconds: 50),
      );
      await gesture.up();
      await tester.pump();

      expect(holdEndedCount, 1);
    });

    testWidgets(
      'regression: losing hold-capability mid-hold (e.g. connection drop) '
      'still fires onHoldEnd, not silently dropped',
      (tester) async {
        var holdEndedCount = 0;
        final holdCapable = ValueNotifier<bool>(true);
        addTearDown(holdCapable.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: holdCapable,
                builder: (context, capable, _) => RemotePressFeedback(
                  onPressed: () {},
                  onHoldStart: capable ? () {} : null,
                  onHoldEnd: capable ? () => holdEndedCount++ : null,
                  child: const SizedBox(
                    width: kRemotePressFeedbackTestChildSize,
                    height: kRemotePressFeedbackTestChildSize,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.startGesture(kRemotePressFeedbackTestTapOffset);
        await tester.pump(
          kRemoteHoldThreshold + const Duration(milliseconds: 50),
        );

        // Simulates the real trigger: connection state changes mid-hold,
        // causing controlsEnabled (and therefore hold-capability) to flip —
        // with no pointer event involved, only a parent rebuild.
        holdCapable.value = false;
        await tester.pump();

        expect(
          holdEndedCount,
          1,
          reason:
              'the held key must be released on the TV when the button '
              'loses hold-capability mid-gesture, not left stuck down',
        );
      },
    );

    testWidgets('watchdog force-ends the hold if the release event is lost', (
      tester,
    ) async {
      var holdEndedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemotePressFeedback(
              onPressed: () {},
              onHoldStart: () {},
              onHoldEnd: () => holdEndedCount++,
              child: const SizedBox(
                width: kRemotePressFeedbackTestChildSize,
                height: kRemotePressFeedbackTestChildSize,
              ),
            ),
          ),
        ),
      );

      await tester.startGesture(kRemotePressFeedbackTestTapOffset);
      // Cross the hold threshold, then the watchdog ceiling, without ever
      // releasing — simulates a lost end/cancel event (e.g. backgrounded
      // app), per goal-long-press-key.md fact #19.
      await tester.pump(kRemoteHoldThreshold + kRemoteHoldWatchdogTimeout);

      expect(holdEndedCount, 1);
    });
  });
}
