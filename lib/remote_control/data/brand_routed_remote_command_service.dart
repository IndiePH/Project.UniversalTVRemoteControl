import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/application/text_compatibility_error.dart';
import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';
import 'package:one_remote/remote_control/application/remote_command_service.dart';
import 'package:one_remote/remote_control/application/transport_log_provider.dart';
import 'package:one_remote/remote_control/application/transport_log_reader.dart';
import 'package:one_remote/remote_control/application/transport_log_reader_provider.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Routes generic remote actions to a brand-specific adapter.
///
/// Capability checks are enforced here so UI code can stay brand-agnostic.
class BrandRoutedRemoteCommandService
    implements RemoteCommandService, TransportLogReaderProvider {
  BrandRoutedRemoteCommandService({
    required List<TvBrandAdapter> adapters,
    required VariantResolutionRegistry variantRegistry,
    required LocalizedStrings localizedStrings,
  }) : _adapters = {for (final a in adapters) (a.brand, a.protocolVariant): a},
       _variantRegistry = variantRegistry,
       _localizedStrings = localizedStrings;

  final Map<(TvBrand, String), TvBrandAdapter> _adapters;
  final VariantResolutionRegistry _variantRegistry;
  final LocalizedStrings _localizedStrings;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    await _adapterFor(
      device.brand,
      device.protocolVariant,
    )?.unpairDevice(device: device);
  }

  @override
  Future<CommandDispatchResult> preparePairing({
    required TvDevice device,
  }) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        _localizedStrings.pairingNoAdapter(device.brand.name),
      );
    }
    try {
      await adapter.preparePairing(device: device);
      final info = await adapter.queryDeviceInfo(device: device);
      final variant = _variantRegistry.resolve(brand: device.brand, info: info);
      final capabilities = const TvCapabilities().capabilitiesFor(
        device.brand,
        variant,
      );
      final enriched = device.copyWith(
        capabilities: capabilities,
        protocolVariant: variant,
        modelIdentifier: info?.modelIdentifier,
      );
      return CommandDispatchResult.success(
        _localizedStrings.pairingApproved(device.displayName),
        device: enriched,
      );
    } catch (error) {
      return CommandDispatchResult.failure(
        _localizedStrings.pairingFailed(device.displayName),
        exception: error,
      );
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
        _localizedStrings.pairingNoAdapter(device.brand.name),
      );
    }
    try {
      await adapter.submitPairingCode(
        device: device,
        fourDigitPin: fourDigitPin,
      );
      return CommandDispatchResult.success(
        _localizedStrings.pairingCodeAccepted(device.displayName),
      );
    } on UnsupportedError catch (error) {
      return CommandDispatchResult.unsupported(
        error.message?.toString() ?? '$error',
      );
    } catch (error) {
      return CommandDispatchResult.failure(
        _localizedStrings.pairingCodeSubmitFailed(device.displayName),
        exception: error,
      );
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
        _localizedStrings.pairingNoAdapter(device.brand.name),
      );
    }
    if (!adapter.supportedCommands.contains(command)) {
      return CommandDispatchResult.unsupported(
        _localizedStrings.remoteCommandUnsupported(command.name, device.brand.name),
      );
    }
    try {
      await adapter.sendCommand(device: device, command: command);
      return CommandDispatchResult.success(
        _localizedStrings.remoteCommandSent(command.name),
      );
    } catch (error) {
      return CommandDispatchResult.failure(
        _localizedStrings.remoteCommandFailed(device.displayName),
        exception: error,
      );
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
        _localizedStrings.pairingNoAdapter(device.brand.name),
      );
    }
    if (!adapter.supportsTextInput) {
      return CommandDispatchResult.unsupported(
        _localizedStrings.remoteTextInputUnsupported(device.brand.name),
      );
    }
    try {
      await adapter.sendText(device: device, text: text);
      return CommandDispatchResult.success(
        _localizedStrings.remoteTextSent(text),
      );
    } on TextInputCompatibilityException catch (error) {
      final message = switch (error.error) {
        TextCompatibilityError.lgImeFocusRequired =>
          _localizedStrings.remoteTextLgImeFocusRequired,
        TextCompatibilityError.samsungScreenNotAcceptingInput =>
          _localizedStrings.remoteTextSamsungCompatibilityError,
      };
      return CommandDispatchResult.compatibility(message);
    } catch (error) {
      return CommandDispatchResult.failure(
        _localizedStrings.remoteTextFailed(device.displayName),
        exception: error,
      );
    }
  }

  @override
  Set<RemoteCommand> supportedCommandsFor({required TvDevice device}) {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    return adapter?.supportedCommands ?? <RemoteCommand>{};
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
  Stream<ConnectionState> watchConnectionState({required TvDevice device}) {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter == null) {
      return Stream<ConnectionState>.value(ConnectionState.disconnected);
    }
    return adapter.watchConnectionState(device);
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
