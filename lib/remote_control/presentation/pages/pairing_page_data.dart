import 'package:intl/intl.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_identity_migration_repository.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/discovered_device_support.dart';
import 'package:one_remote/remote_control/application/layout_identity_migration_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/data/device_reconciliation_service.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/domain/models/device_support_tier.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Read/derive data used by `PairingPage` presentation state.
final class PairingPageData {
  const PairingPageData._();

  static Future<List<String>> loadRecentManualIps(
    DeviceRepository deviceRepository,
  ) {
    return deviceRepository.getRecentManualIps();
  }

  static Future<PairingMetadataSnapshot> loadPairingMetadata(
    DeviceRepository deviceRepository,
  ) async {
    final savedDevices = await deviceRepository.getSavedDevices();
    final savedIds = <String>{};
    final pairingHistory = <String, DateTime>{};

    for (final device in savedDevices) {
      savedIds.add(device.id);
      final pairedAt = await deviceRepository.getLastSuccessfulPairingAt(
        device.id,
      );
      if (pairedAt != null) {
        pairingHistory[device.id] = pairedAt;
      }
    }

    return PairingMetadataSnapshot(
      savedDevices: savedDevices,
      savedDeviceIds: savedIds,
      pairingHistoryByDeviceId: pairingHistory,
    );
  }

  static Future<List<TvDevice>> discoverDevices(
    DeviceDiscoveryService discoveryService,
  ) async {
    final devices = await discoveryService.discoverDevices();
    return List<TvDevice>.from(devices)
      ..sort(DiscoveredDeviceSupport.compareForDiscoveryList);
  }

  /// Reconciles freshly [discovered] devices against [saved] devices by stable
  /// id and persists any saved device whose LAN host has changed, so a paired
  /// TV that moved to a new IP (e.g. after a router reboot) keeps working
  /// without re-pairing. Also re-registers the new `host -> stableId` binding
  /// in [identityRegistry] so transports address the current IP this session.
  ///
  /// Best-effort: persistence failures are swallowed so a discovery scan never
  /// breaks because a background re-key failed. No-op when no registry is
  /// wired (degrades to legacy IP-derived behaviour). Legacy records are
  /// migrated only when the repository exposes the optional migration
  /// capability; ordinary test/in-memory repositories remain unchanged.
  static Future<void> reconcileDiscovery({
    required List<TvDevice> discovered,
    required List<TvDevice> saved,
    required DeviceIdentityRegistry? identityRegistry,
    required DeviceRepository deviceRepository,
    LayoutRepository? layoutRepository,
  }) async {
    if (identityRegistry == null) return;
    final result = DeviceReconciliationService(
      identityRegistry: identityRegistry,
    ).reconcile(discovered: discovered, saved: saved);
    for (final updated in result.updatedSavedDevices) {
      try {
        await deviceRepository.saveDevice(updated);
      } catch (_) {
        // Best-effort: a failed persist does not invalidate the scan. The
        // in-session registry binding still lets transports reach the TV;
        // the persisted host is corrected on a later successful reconcile.
      }
    }

    final deviceMigrator = deviceRepository is DeviceIdentityMigrationRepository
        ? deviceRepository as DeviceIdentityMigrationRepository
        : null;
    if (deviceMigrator == null) return;

    final layoutMigrator = layoutRepository is LayoutIdentityMigrationRepository
        ? layoutRepository as LayoutIdentityMigrationRepository
        : null;
    for (final rekey in result.legacyRekeys) {
      var layoutCopied = false;
      if (layoutMigrator != null) {
        try {
          layoutCopied = await layoutMigrator.migrateLayoutIdentity(
            legacyDeviceId: rekey.legacy.id,
            newDeviceId: rekey.migrated.id,
          );
        } catch (_) {
          // Do not retire the legacy device if its layout could not be copied.
          continue;
        }
      }
      try {
        final migrated = await deviceMigrator.migrateDeviceIdentity(
          legacyId: rekey.legacy.id,
          device: rekey.migrated,
        );
        if (migrated && layoutMigrator != null && layoutCopied) {
          await layoutMigrator.completeLayoutIdentityMigration(
            legacyDeviceId: rekey.legacy.id,
          );
        }
      } catch (_) {
        // Best-effort: the legacy record and its host-keyed secrets remain
        // available if any part of this migration fails.
      }
    }
  }

  static String? discoverySupportNoteForDevice({
    required TvDevice device,
    required AppLocalizations l10n,
  }) {
    return switch (DiscoveredDeviceSupport.tierFor(device)) {
      DeviceSupportTier.full => null,
      DeviceSupportTier.limited => switch (device.brand) {
        TvBrand.hisense => l10n.pairingDiscoveryHisenseLimitedSupport,
        TvBrand.roku => l10n.pairingDiscoveryRokuLimitedSupport,
        _ => l10n.pairingDiscoveryLimitedSupport,
      },
      DeviceSupportTier.experimental =>
        l10n.pairingDiscoveryExperimentalSupport(device.brand.displayName),
    };
  }

  static TvDevice buildManualDevice({
    required TvBrand brand,
    required String ip,
    String protocolVariant = TvDevice.defaultProtocolVariant,
  }) {
    return TvDevice(
      id: '${brand.name}-$protocolVariant-$ip',
      displayName: '${brand.displayName} TV ($ip)',
      brand: brand,
      protocolVariant: protocolVariant,
      capabilities: const TvCapabilities().capabilitiesFor(
        brand,
        protocolVariant,
      ),
      host: ip,
    );
  }

  static bool isValidIpv4(String input) {
    final regExp = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
    );
    return regExp.hasMatch(input);
  }

  static String? pairingNoteForDevice({
    required String deviceId,
    required Set<String> savedDeviceIds,
    required Map<String, DateTime> pairingHistoryByDeviceId,
    required AppLocalizations l10n,
  }) {
    if (!savedDeviceIds.contains(deviceId)) {
      return null;
    }
    final pairedAt = pairingHistoryByDeviceId[deviceId];
    if (pairedAt == null) {
      return l10n.pairingNotePreviouslyPaired;
    }
    final formatted = DateFormat.yMd().add_Hm().format(pairedAt.toLocal());
    return l10n.pairingNotePreviouslyPairedAt(formatted);
  }
}

final class PairingMetadataSnapshot {
  const PairingMetadataSnapshot({
    required this.savedDevices,
    required this.savedDeviceIds,
    required this.pairingHistoryByDeviceId,
  });

  final List<TvDevice> savedDevices;
  final Set<String> savedDeviceIds;
  final Map<String, DateTime> pairingHistoryByDeviceId;
}
