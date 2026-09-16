import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_mqtt_transport_client.dart';
import 'package:one_remote/remote_control/data/adapters/hisense/hisense_pairing_auth_store.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';

/// Regression coverage for the goal-doc's symptom 1 (Hisense side) and
/// Design item 7 (pause/resume the connectivity poll while backgrounded).
///
/// Exercises the real [HisenseMqttTransportClient] against a minimal fake
/// TCP broker rather than a fake transport double, since both behaviors
/// under test (the deleted self-reconnect, and the poll-timer pause/resume)
/// live entirely inside this class's own polling logic. The fake broker
/// only needs to complete an MQTT CONNACK handshake -- a 4-byte reply -- to
/// get `mqtt_client` into a "connected" state; nothing else about the
/// protocol matters here.
void main() {
  late ServerSocket broker;
  var acceptCount = 0;
  final acceptedSockets = <Socket>[];
  late StreamSubscription<Socket> brokerSub;

  setUp(() async {
    acceptCount = 0;
    acceptedSockets.clear();
    broker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    brokerSub = broker.listen((socket) {
      acceptCount++;
      acceptedSockets.add(socket);
      socket.listen(
        (_) {
          // Any inbound data is assumed to be the CONNECT packet -- reply
          // with a minimal "accepted" CONNACK (fixed header + session
          // present=0 + return code=0).
          socket.add(const [0x20, 0x02, 0x00, 0x00]);
        },
        onError: (_) {},
        cancelOnError: false,
      );
    });
  });

  tearDown(() async {
    await brokerSub.cancel();
    await broker.close();
  });

  HisenseMqttTransportClient buildClient() => HisenseMqttTransportClient(
    hostResolver: (_) => '127.0.0.1',
    pairingAuthStore: _FakeHisensePairingAuthStore(),
    usePlaintextMqtt: true,
    brokerPort: broker.port,
  );

  test(
    'poll tick detecting a drop emits disconnected without self-reconnecting',
    () async {
      final transport = buildClient();
      final states = <ConnectionState>[];
      final stateSub = transport
          .watchConnectionState('device-1')
          .listen(states.add);
      addTearDown(stateSub.cancel);

      await transport.connect(deviceId: 'device-1');
      expect(acceptCount, 1);
      expect(states.last, ConnectionState.connected);

      // Simulate the TV dropping the connection server-side (mirrors PR #9's
      // changelog scenario of the TV closing after unanswered pings), not
      // the broker going offline -- the poll's own reachability probe would
      // otherwise be unable to distinguish "TV dropped us" from "network
      // down," and a still-listening broker is what makes it possible to
      // observe whether a reconnect attempt is made below.
      await acceptedSockets.single.close();

      // The poll interval is a fixed 8s in production code; wait past the
      // first tick that should notice the drop.
      await Future<void>.delayed(const Duration(seconds: 9));

      expect(
        states,
        contains(ConnectionState.disconnected),
        reason: 'the poll tick must still detect and emit the drop',
      );
      expect(
        acceptCount,
        1,
        reason:
            'HisenseMqttTransportClient must not self-reconnect after its '
            'poll detects a drop -- ReconnectionRetryController is the sole '
            'retry authority now.',
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'pauseMonitoring stops the poll loop; resumeMonitoring restarts it with '
    'one immediate check, without touching the underlying MQTT session',
    () async {
      final transport = buildClient();
      final states = <ConnectionState>[];
      final stateSub = transport
          .watchConnectionState('device-1')
          .listen(states.add);
      addTearDown(stateSub.cancel);

      await transport.connect(deviceId: 'device-1');
      expect(acceptCount, 1);
      // Only pause/resume's own effect on state matters below; the initial
      // connect() sequence (connecting -> connected) is not.
      states.clear();

      await transport.pauseMonitoring(deviceId: 'device-1');

      // Wait past the 8s poll interval: a paused poll must produce no
      // further reachability probe against the broker.
      await Future<void>.delayed(const Duration(seconds: 9));
      expect(
        acceptCount,
        1,
        reason: 'pauseMonitoring must cancel the poll timer entirely',
      );

      await transport.resumeMonitoring(deviceId: 'device-1');
      // resumeMonitoring's own immediate check is a raw reachability probe
      // (connect+destroy) against the broker port, separate from the
      // long-lived MQTT session -- expect it right away, not after another
      // 8s tick.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        acceptCount,
        2,
        reason:
            'resumeMonitoring must trigger one immediate fresh check, not '
            'wait for the next periodic tick',
      );

      // Neither call touched the underlying MQTT session: nothing other
      // than "connected" was ever emitted after the initial connect() (a
      // session teardown would have shown up as an intervening
      // disconnected/connecting emission).
      expect(
        states.where((s) => s != ConnectionState.connected),
        isEmpty,
        reason:
            'pauseMonitoring/resumeMonitoring must only affect the poll '
            'loop, never the underlying MQTT session',
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

/// Avoids the persisted-PIN-authorization gateway entirely -- reports every
/// host as already paired so `connect()` reaches "connected" cleanly
/// instead of throwing `PinRequiredException` (which would still start the
/// poll timer, since that happens inside `_ensureConnected` before the PIN
/// check, but adds an irrelevant exception to every test).
class _FakeHisensePairingAuthStore extends HisensePairingAuthStore {
  @override
  Future<bool> isHostPaired(String host) async => true;

  @override
  Future<void> markHostPaired(String host) async {}

  @override
  Future<void> clearHost(String host) async {}
}
