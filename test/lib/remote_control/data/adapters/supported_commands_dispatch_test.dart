import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/hisense_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_google_tv_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_legacy_wifi_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/tcl_roku_adapter.dart';
import 'package:one_remote/remote_control/debug/fake_android_tv_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_hisense_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_lg_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_roku_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_samsung_transport_client.dart';
import 'package:one_remote/remote_control/debug/fake_tcl_legacy_transport_client.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Guards the gap `CommandPayload`'s sealed-class exhaustiveness check can't see: a
/// brand's key mapper returning a payload type its own `sendCommand` switch doesn't
/// have a real case for (falls into the `default: throw UnsupportedError` branch).
/// The compiler only proves every switch handles every payload *type* that exists
/// anywhere in the app — it can't prove a given brand's *supported* commands actually
/// dispatch. This test proves that instead, per adapter, without hand-listing commands
/// per brand (which would itself rot as commands are added/removed from each key map).
void main() {
  final adapters = <TvBrandAdapter>[
    SamsungAdapter(transportClient: FakeSamsungTransportClient()),
    LgAdapter(transportClient: FakeLgTransportClient()),
    AndroidTvAdapter(transportClient: FakeAndroidTvTransportClient()),
    TclGoogleTvAdapter(transportClient: FakeAndroidTvTransportClient()),
    TclRokuAdapter(transportClient: FakeRokuTransportClient()),
    HisenseAdapter(transportClient: FakeHisenseTransportClient()),
    TclLegacyWifiAdapter(transportClient: FakeTclLegacyTransportClient()),
  ];

  for (final adapter in adapters) {
    final device = TvDevice(
      id: '${adapter.brand.name}-${adapter.protocolVariant}-dispatch-test',
      displayName: '${adapter.brand.name} dispatch test TV',
      brand: adapter.brand,
      protocolVariant: adapter.protocolVariant,
      capabilities: const {
        DeviceCapability.keyCommands,
        DeviceCapability.powerControl,
      },
    );

    group('${adapter.brand.name} (${adapter.protocolVariant}): every supported '
        'command dispatches', () {
      for (final command in adapter.supportedCommands) {
        test('$command does not hit the unsupported-payload-type path', () async {
          try {
            await adapter.sendCommand(device: device, command: command);
          } on UnsupportedError catch (e) {
            fail(
              '${adapter.brand.name} claims to support $command (its key map '
              "returned a payload for it) but sendCommand's switch doesn't "
              'handle that payload type: ${e.message}',
            );
          } catch (_) {
            // Any other exception (pairing/auth preconditions, etc.) is unrelated
            // to payload-type dispatch, which is the only thing this test guards.
          }
        });
      }
    });
  }
}
