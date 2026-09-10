import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_cert_subject_mac_parser.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// TEMPORARY migration shim, not permanent code — do not extend or generalize.
///
/// Migrates a device saved under the old whole-cert-hash id (`androidtv-<sha256>`) onto the newer
/// `androidtv-<mac>` id, so affected users don't need to manually re-pair. Temporary because it
/// trusts MAC extraction verified against only two device shapes, and the population needing it
/// only shrinks over time. Full rationale, removal deadline (~2026-11-10), and exit criteria:
/// `references/tech-debt-list.md`. Introduced in commit 4f998a2 — read that commit's message for
/// the design discussion behind why it's shaped this way.
final class AndroidTvLegacySha256IdMigrator {
  const AndroidTvLegacySha256IdMigrator._();

  /// Single kill switch. Flip to `false` (or delete this file and its call site) to retire.
  static const bool enabled = true;

  /// Matches `AndroidTvTcpTransportClient`'s own remote-control port and probe timeout --
  /// duplicated rather than shared, so this file has zero footprint on the permanent transport
  /// client and can be deleted without touching it.
  static const int _remotePort = 6466;
  static const Duration _probeTimeout = Duration(seconds: 2);

  static final RegExp _legacyShaIdPattern = RegExp(r'^androidtv-[0-9a-f]{64}$');

  /// For every discovered Android TV, checks whether a live connection's certificate hash matches
  /// a saved device still on the old `androidtv-<sha256>` scheme, and migrates it onto
  /// `androidtv-<mac>` if the certificate's subject also yields a parseable MAC. Runs independently
  /// of, and does not affect, this scan's discovered ids. Best-effort throughout: a connection
  /// failure for any one device does not affect the others.
  static Future<void> migrate({
    required List<TvDevice> discovered,
    required List<TvDevice> saved,
    required AndroidTvCertificateStore certStore,
    required DeviceRepository repository,
  }) async {
    if (!enabled) return;

    final legacyByShaId = <String, TvDevice>{
      for (final device in saved)
        if (device.brand == TvBrand.androidTv &&
            _legacyShaIdPattern.hasMatch(device.id))
          device.id: device,
    };
    if (legacyByShaId.isEmpty) return;

    await Future.wait(
      discovered
          .where((d) => d.brand == TvBrand.androidTv)
          .map((d) => _migrateOne(d, legacyByShaId, certStore, repository)),
    );
  }

  static Future<void> _migrateOne(
    TvDevice discovered,
    Map<String, TvDevice> legacyByShaId,
    AndroidTvCertificateStore certStore,
    DeviceRepository repository,
  ) async {
    final host = discovered.resolvedHost.trim();
    if (host.isEmpty) return;

    SecureSocket? socket;
    try {
      final ctx = await certStore.clientContext;
      socket = await SecureSocket.connect(
        host,
        _remotePort,
        context: ctx,
        onBadCertificate: (_) => true,
        timeout: _probeTimeout,
      );
      final rawDer = socket.peerCertificate?.der;
      if (rawDer == null) return;

      final der = Uint8List.fromList(rawDer);
      final legacyId = AndroidTvCertificateStore.stableIdFromServerCertificate(der);
      final legacyDevice = legacyByShaId[legacyId];
      if (legacyDevice == null) return;

      final mac = AndroidTvCertSubjectMacParser.parseFromDer(der);
      if (mac == null) return;

      await repository.saveDevice(legacyDevice.copyWith(id: 'androidtv-$mac'));
    } catch (_) {
      // Best-effort -- a failed probe for one device must not affect others, and this migration
      // is itself best-effort by design (see class doc comment).
    } finally {
      socket?.destroy();
    }
  }
}
