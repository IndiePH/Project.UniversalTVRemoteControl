import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/analytics/analytics_service.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/monetization/pro_entitlement_service.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/data/manual_add_variant_probe.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/data/fake_device_discovery_service.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_debug_sheet.dart';

/// Groups remote-home navigation and debug actions outside widget state.
final class RemoteHomeActions {
  const RemoteHomeActions._();

  static const bool _compileUseFakeTransports = bool.fromEnvironment(
    'USE_FAKE_TRANSPORTS',
    defaultValue: false,
  );
  static const TvDevice _fakeSamsungProbeDevice = TvDevice(
    id: 'samsung-living-room',
    displayName: 'Samsung QLED - Living Room',
    brand: TvBrand.samsung,
    capabilities: {
      DeviceCapability.keyCommands,
      DeviceCapability.textInput,
      DeviceCapability.powerControl,
    },
  );

  static Future<TvDevice?> openPairing({
    required BuildContext context,
    required RemoteCommandService commandService,
    required DeviceDiscoveryService discoveryService,
    required DeviceRepository deviceRepository,
    LayoutRepository? layoutRepository,
    required ProEntitlementService proEntitlementService,
    required String? activeDeviceId,
  }) async {
    final sl = GetIt.instance;
    if (sl.isRegistered<AnalyticsService>()) {
      unawaited(sl<AnalyticsService>().pairingStart());
    }
    final env = GetIt.instance<AppEnvironment>();
    final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
    final useFakeTransports = stored ?? _compileUseFakeTransports;
    final fakeTransportAvailable =
        env == AppEnvironment.debug && useFakeTransports
        ? await _isFakeTransportRuntimeActive(commandService)
        : false;
    final resolvedDiscoveryService =
        env == AppEnvironment.debug &&
            useFakeTransports &&
            fakeTransportAvailable
        ? FakeDeviceDiscoveryService()
        : discoveryService;

    if (!context.mounted) return null;

    final result = await Navigator.of(context).push<TvDevice>(
      MaterialPageRoute(
        builder: (_) => PairingPage(
          commandService: commandService,
          discoveryService: resolvedDiscoveryService,
          deviceRepository: deviceRepository,
          stepsRegistry: GetIt.instance<PrePairingStepsRegistry>(),
          hintRegistry: GetIt.instance<PairingProgressHintRegistry>(),
          reachabilityService: GetIt.instance<TvReachabilityService>(),
          proEntitlementService: proEntitlementService,
          activeDeviceId: activeDeviceId,
          identityRegistry: sl.isRegistered<DeviceIdentityRegistry>()
              ? sl<DeviceIdentityRegistry>()
              : null,
          layoutRepository: layoutRepository,
          manualAddVariantProbe: sl.isRegistered<ManualAddVariantProbe>()
              ? sl<ManualAddVariantProbe>()
              : null,
        ),
      ),
    );
    if (result == null) {
      if (sl.isRegistered<AnalyticsService>()) {
        unawaited(sl<AnalyticsService>().pairingCancel());
      }
    } else {
      if (sl.isRegistered<AnalyticsService>()) {
        unawaited(
          sl<AnalyticsService>().pairingSuccess(tvBrand: result.brand.name),
        );
      }
    }
    return result;
  }

  static Future<bool> copyLatestTransportLog({
    required TransportLogReader transportLogReader,
  }) async {
    final logs = await transportLogReader.readLatestLogForSharing();
    if (logs == null || logs.trim().isEmpty) {
      return false;
    }
    await Clipboard.setData(ClipboardData(text: logs));
    return true;
  }

  static Future<bool> copyDiagnosticsReport({
    required AppDiagnosticsRecorder recorder,
  }) async {
    final report = recorder.buildReport().trim();
    if (report.isEmpty) {
      return false;
    }
    await Clipboard.setData(ClipboardData(text: report));
    return true;
  }

  static Future<void> showTransportDebugSheet({
    required BuildContext context,
    required Future<bool> Function() onCopyTransportLogs,
    required Future<void> Function() onCopyRuntimeFlagsTemplate,
    TvDevice? activeDevice,
    Future<TvDeviceInfo?> Function({required TvDevice device})? queryDeviceInfo,
  }) async {
    final env = GetIt.instance<AppEnvironment>();
    final isDebug = env == AppEnvironment.debug;
    final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
    var pendingFake = stored ?? _compileUseFakeTransports;

    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return RemoteHomeDebugSheet(
              activeDevice: activeDevice,
              queryDeviceInfo: queryDeviceInfo,
              showTransportToggle: isDebug,
              useFakeTransports: pendingFake,
              onUseFakeTransportsChanged: (value) async {
                await TransportDebugSettings.writeUseFakeTransports(value);
                setModalState(() {
                  pendingFake = value;
                });
              },
              onCopyTransportLogs: () {
                unawaited(() async {
                  final didCopy = await onCopyTransportLogs();
                  if (didCopy && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                }());
              },
              onCopyRuntimeFlagsTemplate: () {
                Navigator.pop(sheetContext);
                unawaited(onCopyRuntimeFlagsTemplate());
              },
            );
          },
        );
      },
    );
  }

  static Future<bool> _isFakeTransportRuntimeActive(
    RemoteCommandService commandService,
  ) async {
    try {
      final info = await commandService.queryDeviceInfo(
        device: _fakeSamsungProbeDevice,
      );
      return info?.modelIdentifier == 'FAKE-SAMSUNG';
    } catch (_) {
      return false;
    }
  }
}
