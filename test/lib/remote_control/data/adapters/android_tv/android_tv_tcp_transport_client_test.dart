import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_exceptions.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_tcp_transport_client.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';

/// Regression coverage for the goal-doc's symptom 1: after PR #9
/// (`_onRemoteSocketDone` scheduling its own reconnect 3s after a socket
/// close) and PR #32 (`ReconnectionRetryController` added as a second, page
/// -level retry authority) shipped together with no coordination between
/// them, the app had two independent reconnect schedulers. This branch
/// deleted the transport-level one; this test guards against it quietly
/// coming back.
///
/// Exercises the real `AndroidTvTcpTransportClient` against a loopback TLS
/// server rather than a fake transport double, since the removed behavior
/// lived entirely inside this class's own socket-close handling — a fake
/// would test nothing. The only thing faked is [AndroidTvCertificateStore],
/// which normally persists to disk via `path_provider`; that's a genuine
/// external dependency (not the behavior under test), so it's faked to
/// avoid needing platform-channel mocking for a regression test that has
/// nothing to do with certificate persistence.
void main() {
  late String certPem;
  late String keyPem;

  setUpAll(() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;
    final csr = X509Utils.generateRsaCsrPem(
      {'CN': 'fake-android-tv'},
      privateKey,
      publicKey,
    );
    certPem = X509Utils.generateSelfSignedCertificate(privateKey, csr, 1);
    keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
  });

  test(
    'no self-scheduled reconnect after the remote socket closes',
    () async {
      final serverContext = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(certPem))
        ..usePrivateKeyBytes(utf8.encode(keyPem));
      final server = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        6466,
        serverContext,
      );
      addTearDown(server.close);

      var acceptedConnections = 0;
      final serverSub = server.listen((socket) {
        acceptedConnections++;
        // The TV closes immediately -- mirrors PR #9's changelog scenario
        // (TV closes after ~16s of unanswered pings) without needing to
        // actually wait 16s or complete the RemoteConfigure handshake:
        // `_onRemoteSocketDone` is wired up as soon as the TLS socket
        // connects, before the handshake, so this is enough to trigger it.
        socket.destroy();
      });
      addTearDown(serverSub.cancel);

      final transport = AndroidTvTcpTransportClient(
        hostResolver: (_) => '127.0.0.1',
        certStore: _FakeAndroidTvCertificateStore(),
      );

      final states = <ConnectionState>[];
      final stateSub = transport
          .watchConnectionState('device-1')
          .listen(states.add);
      addTearDown(stateSub.cancel);

      await expectLater(
        transport.connect(deviceId: 'device-1'),
        throwsA(isA<AndroidTvConnectionException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(acceptedConnections, 1);
      expect(states, contains(ConnectionState.disconnected));

      // The regression this guards against: the deleted code scheduled its
      // own reconnect 3s after this exact point. Wait comfortably past that
      // window and confirm the transport never dialed again on its own.
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(
        acceptedConnections,
        1,
        reason:
            'AndroidTvTcpTransportClient must not self-schedule a reconnect '
            'after the remote socket closes -- ReconnectionRetryController '
            'is the sole retry authority now.',
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}

/// Avoids `path_provider` disk I/O entirely -- neither override touches it,
/// so [AndroidTvCertificateStore]'s real `_ensureInitialized` is never
/// reached. [serverRsaComponents] must report "already paired" so
/// `connect()` routes to the remote-control flow (port 6466, where
/// `_onRemoteSocketDone` lives) instead of the pairing flow (port 6467).
class _FakeAndroidTvCertificateStore extends AndroidTvCertificateStore {
  @override
  Future<SecurityContext> get clientContext async => SecurityContext();

  @override
  Future<(BigInt, BigInt)?> serverRsaComponents(String host) async =>
      (BigInt.one, BigInt.from(65537));
}
