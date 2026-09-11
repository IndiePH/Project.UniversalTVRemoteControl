import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/data/in_memory_device_repository.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/widgets/pairing_page_sections.dart';

const _device = TvDevice(
  id: 'samsung-uuid-1',
  displayName: 'Living Room TV',
  brand: TvBrand.samsung,
  capabilities: {DeviceCapability.keyCommands},
  host: '192.168.1.10',
);

class _AlwaysUnreachable implements TvReachabilityService {
  int callCount = 0;

  @override
  Future<bool> isReachable(TvDevice device) async {
    callCount++;
    return false;
  }
}

/// Throws after yielding at least once, so the indicator's own `await` has
/// already attached before the error fires -- an eagerly-created
/// `Future.error` would otherwise report as an unhandled zone error before
/// any listener exists, which is a test-authoring pitfall, not something
/// this failure mode itself should trigger.
Future<void> _reconcileThatThrows() async {
  await Future<void>.delayed(Duration.zero);
  throw Exception('reconciliation blew up');
}

Widget _wrap({
  required TvReachabilityService reachabilityService,
  required Future<void>? reconcileInFlight,
  DeviceRepository? deviceRepository,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PairedTvListItem(
        device: _device,
        pairedAt: null,
        isActive: false,
        switchLocked: false,
        reachabilityService: reachabilityService,
        deviceRepository: deviceRepository ?? InMemoryDeviceRepository(),
        reconcileInFlight: reconcileInFlight,
        onConfirmDismiss: (_) async => false,
        onRename: () {},
        onInfo: () {},
        onTap: () {},
      ),
    ),
  );
}

void main() {
  group('PairedTvListItem connection indicator', () {
    testWidgets(
      'falls back to grey instead of crashing when the shared reconciliation '
      'pass throws',
      (tester) async {
        final reachability = _AlwaysUnreachable();

        await tester.pumpWidget(
          _wrap(
            reachabilityService: reachability,
            reconcileInFlight: _reconcileThatThrows(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        expect(find.byIcon(Icons.wifi), findsNothing);
        expect(
          reachability.callCount,
          1,
          reason:
              'a failed shared pass gives up rather than re-probing the '
              'same host it already knows is unreachable',
        );
      },
    );

    testWidgets('shows grey when there is no reconciliation pass to await', (
      tester,
    ) async {
      final reachability = _AlwaysUnreachable();

      await tester.pumpWidget(
        _wrap(reachabilityService: reachability, reconcileInFlight: null),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(reachability.callCount, 1);
    });
  });
}
