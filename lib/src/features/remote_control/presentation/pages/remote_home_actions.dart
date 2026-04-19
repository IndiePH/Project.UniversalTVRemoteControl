import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_remote/src/features/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/src/features/remote_control/application/device_repository.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/src/features/remote_control/presentation/pages/pairing_page.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_home_debug_sheet.dart';

/// Groups remote-home navigation and debug actions outside widget state.
final class RemoteHomeActions {
  const RemoteHomeActions._();

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

  static Future<bool> copyLatestSamsungTextLog({
    required TransportLogReader transportLogReader,
  }) async {
    final logs = await transportLogReader.readLatestSamsungLogForSharing();
    if (logs == null || logs.trim().isEmpty) {
      return false;
    }
    await Clipboard.setData(ClipboardData(text: logs));
    return true;
  }

  static void showTransportDebugSheet({
    required BuildContext context,
    required bool showTransportToggle,
    required bool useFakeTransports,
    required bool compileTimeUseFakeTransports,
    required Future<void> Function(bool value)? onUseFakeTransportsChanged,
    required Future<void> Function() onCopySamsungTextLogs,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return RemoteHomeDebugSheet(
              showTransportToggle: showTransportToggle,
              useFakeTransports: useFakeTransports,
              compileTimeUseFakeTransports: compileTimeUseFakeTransports,
              onUseFakeTransportsChanged: (value) async {
                final changeMode = onUseFakeTransportsChanged;
                if (changeMode == null) {
                  return;
                }
                await changeMode(value);
                setModalState(() {});
              },
              onCopySamsungTextLogs: () {
                Navigator.pop(sheetContext);
                unawaited(onCopySamsungTextLogs());
              },
            );
          },
        );
      },
    );
  }
}
