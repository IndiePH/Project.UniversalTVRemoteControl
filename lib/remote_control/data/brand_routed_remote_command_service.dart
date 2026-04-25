import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_provider.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/application/transport_log_reader_provider.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Routes generic remote actions to a brand-specific adapter.
///
/// Capability checks are enforced here so UI code can stay brand-agnostic.
class BrandRoutedRemoteCommandService
    implements RemoteCommandService, TransportLogReaderProvider {
  BrandRoutedRemoteCommandService({required List<TvBrandAdapter> adapters})
    : _adapters = {for (final adapter in adapters) adapter.brand: adapter};

  final Map<TvBrand, TvBrandAdapter> _adapters;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    await _adapterFor(device.brand)?.unpairDevice(device: device);
  }

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async {
    final adapter = _adapterFor(device.brand);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        'No adapter configured for ${device.brand.name}.',
      );
    }
    try {
      await adapter.preparePairing(device: device);
      return CommandDispatchResult.success(
        'Pairing approved for ${device.displayName}.',
      );
    } catch (error) {
      return CommandDispatchResult.failure('Something went wrong.', exception: error);
    }
  }

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    final adapter = _adapterFor(device.brand);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        'No adapter configured for ${device.brand.name}.',
      );
    }
    try {
      await adapter.submitPairingCode(
        device: device,
        fourDigitPin: fourDigitPin,
      );
      return CommandDispatchResult.success(
        'Pairing code accepted for ${device.displayName}.',
      );
    } on UnsupportedError catch (error) {
      return CommandDispatchResult.unsupported(error.message?.toString() ?? '$error');
    } catch (error) {
      return CommandDispatchResult.failure('Something went wrong.', exception: error);
    }
  }

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final adapter = _adapterFor(device.brand);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        'No adapter configured for ${device.brand.name}.',
      );
    }
    if (!adapter.supportedCommands.contains(command)) {
      return CommandDispatchResult.unsupported(
        'Command ${command.name} is not supported for ${device.brand.name}.',
      );
    }
    try {
      await adapter.sendCommand(device: device, command: command);
      return CommandDispatchResult.success('Sent: ${command.name}');
    } catch (error) {
      return CommandDispatchResult.failure('Something went wrong.', exception: error);
    }
  }

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async {
    final adapter = _adapterFor(device.brand);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        'No adapter configured for ${device.brand.name}.',
      );
    }
    if (!adapter.supportsTextInput) {
      return CommandDispatchResult.unsupported(
        'Text input is not supported for ${device.brand.name}.',
      );
    }
    try {
      await adapter.sendText(device: device, text: text);
      return CommandDispatchResult.success('Text sent: "$text"');
    } on TextInputCompatibilityException catch (error) {
      return CommandDispatchResult.compatibility(error.userMessage);
    } catch (error) {
      return CommandDispatchResult.failure('Something went wrong.', exception: error);
    }
  }

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) {
    final adapter = _adapterFor(device.brand);
    if (adapter == null) {
      return Stream<bool>.value(false);
    }
    if (!adapter.supportsTextInput) {
      return Stream<bool>.value(false);
    }
    if (!device.capabilities.contains(DeviceCapability.textInput)) {
      return Stream<bool>.value(false);
    }
    return adapter.watchRemoteTextInputReady(device);
  }

  @override
  TransportLogReader readerForDevice(TvDevice device) {
    final adapter = _adapterFor(device.brand);
    if (adapter is TransportLogProvider) {
      return (adapter as TransportLogProvider).transportLogReader;
    }
    return const NoopTransportLogReader();
  }

  TvBrandAdapter? _adapterFor(TvBrand brand) => _adapters[brand];
}
