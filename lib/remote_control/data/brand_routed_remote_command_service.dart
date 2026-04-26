import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_provider.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/application/transport_log_reader_provider.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_model_capability_registry.dart';

/// Routes generic remote actions to a brand-specific adapter.
///
/// Capability checks are enforced here so UI code can stay brand-agnostic.
class BrandRoutedRemoteCommandService
    implements RemoteCommandService, TransportLogReaderProvider {
  BrandRoutedRemoteCommandService({
    required List<TvBrandAdapter> adapters,
    required VariantResolutionRegistry variantRegistry,
    required TvModelCapabilityRegistry capabilityRegistry,
  }) : _adapters = {
         for (final a in adapters) (a.brand, a.protocolVariant): a
       },
       _variantRegistry = variantRegistry,
       _capabilityRegistry = capabilityRegistry;

  final Map<(TvBrand, String), TvBrandAdapter> _adapters;
  final VariantResolutionRegistry _variantRegistry;
  final TvModelCapabilityRegistry _capabilityRegistry;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    await _adapterFor(device.brand, device.protocolVariant)?.unpairDevice(
      device: device,
    );
  }

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        'No adapter configured for ${device.brand.name}.',
      );
    }
    try {
      await adapter.preparePairing(device: device);
      final info = await adapter.queryDeviceInfo(device: device);
      final variant = _variantRegistry.resolve(brand: device.brand, info: info);
      final capabilities = _capabilityRegistry.resolve(
        brand: device.brand,
        info: info,
      );
      final enriched = device.copyWith(
        capabilities: capabilities,
        protocolVariant: variant,
        modelIdentifier: info?.modelIdentifier,
      );
      return CommandDispatchResult.success(
        'Pairing approved for ${device.displayName}.',
        device: enriched,
      );
    } catch (error) {
      return CommandDispatchResult.failure('Pairing failed for ${device.displayName}.', exception: error);
    }
  }

  @override
  Future<CommandDispatchResult> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
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
      return CommandDispatchResult.failure('Failed to submit pairing code for ${device.displayName}.', exception: error);
    }
  }

  @override
  Future<CommandDispatchResult> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
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
      return CommandDispatchResult.failure('Failed to send command to ${device.displayName}.', exception: error);
    }
  }

  @override
  Future<CommandDispatchResult> sendText({
    required TvDevice device,
    required String text,
  }) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
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
      return CommandDispatchResult.failure('Failed to send text to ${device.displayName}.', exception: error);
    }
  }

  @override
  Stream<bool> watchRemoteTextInputReady({required TvDevice device}) {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
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
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter is TransportLogProvider) {
      return (adapter as TransportLogProvider).transportLogReader;
    }
    return const NoopTransportLogReader();
  }

  TvBrandAdapter? _adapterFor(TvBrand brand, String variant) =>
      _adapters[(brand, variant)];
}
