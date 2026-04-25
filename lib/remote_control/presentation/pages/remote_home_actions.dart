import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/transport_debug_settings.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
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
  }) {
    return Navigator.of(context).push<TvDevice>(
      MaterialPageRoute(
        builder: (_) => PairingPage(
          commandService: commandService,
          discoveryService: discoveryService,
          deviceRepository: deviceRepository,
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

  static void showTransportDebugSheet({
    required BuildContext context,
    required Future<void> Function() onCopyTransportLogs,
    required Future<void> Function() onCopyRuntimeFlagsTemplate,
  }) {
    final env = GetIt.instance<AppEnvironment>();
    final isDebug = env == AppEnvironment.debug;
    var pendingFake = isDebug;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return RemoteHomeDebugSheet(
              showTransportToggle: isDebug,
              useFakeTransports: pendingFake,
              compileTimeUseFakeTransports: _compileUseFakeTransports,
              onUseFakeTransportsChanged: (value) async {
                await TransportDebugSettings.writeUseFakeTransports(value);
                setModalState(() {
                  pendingFake = value;
                });
              },
              onCopyTransportLogs: () {
                Navigator.pop(sheetContext);
                unawaited(onCopyTransportLogs());
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
