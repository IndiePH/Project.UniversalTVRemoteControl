import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/data/pairing_progress_hint_registry.dart';
import 'package:one_remote/remote_control/data/pre_pairing_steps_registry.dart';
import 'package:one_remote/remote_control/data/fake_device_discovery_service.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_home_debug_sheet.dart';

/// Groups remote-home navigation and debug actions outside widget state.
final class RemoteHomeActions {
  const RemoteHomeActions._();

  static const bool _compileUseFakeTransports = bool.fromEnvironment(
    'USE_FAKE_TRANSPORTS',
    defaultValue: false,
  );

  static Future<TvDevice?> openPairing({
    required BuildContext context,
    required RemoteCommandService commandService,
    required DeviceDiscoveryService discoveryService,
    required DeviceRepository deviceRepository,
    required String? activeDeviceId,
  }) async {
    final env = GetIt.instance<AppEnvironment>();
    final stored = await TransportDebugSettings.readUseFakeTransportsOverride();
    final useFakeTransports = stored ?? _compileUseFakeTransports;
    final resolvedDiscoveryService =
        env == AppEnvironment.debug && useFakeTransports
        ? FakeDeviceDiscoveryService()
        : discoveryService;

    return Navigator.of(context).push<TvDevice>(
      MaterialPageRoute(
        builder: (_) => PairingPage(
          commandService: commandService,
          discoveryService: resolvedDiscoveryService,
          deviceRepository: deviceRepository,
          stepsRegistry: GetIt.instance<PrePairingStepsRegistry>(),
          hintRegistry: GetIt.instance<PairingProgressHintRegistry>(),
          reachabilityService: GetIt.instance<TvReachabilityService>(),
          activeDeviceId: activeDeviceId,
        ),
      ),
    );
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

  static Future<void> showTransportDebugSheet({
    required BuildContext context,
    required Future<bool> Function() onCopyTransportLogs,
    required Future<void> Function() onCopyRuntimeFlagsTemplate,
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
}
