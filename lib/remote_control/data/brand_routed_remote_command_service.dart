import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/remote_control/application/application.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/lg_adapter.dart';
import 'package:one_remote/remote_control/data/adapters/samsung_adapter.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/variant_resolution_registry.dart';
import 'package:one_remote/remote_control/domain/domain.dart';

/// Routes generic remote actions to a brand-specific adapter.
///
/// Capability checks are enforced here so UI code can stay brand-agnostic.
class BrandRoutedRemoteCommandService
    implements RemoteCommandService, TransportLogReaderProvider {
  BrandRoutedRemoteCommandService({
    required List<TvBrandAdapter> adapters,
    required this._variantRegistry,
    required this._localizedStrings,
    this._identityRegistry,
  }) : _adapters = {for (final a in adapters) (a.brand, a.protocolVariant): a};

  final Map<(TvBrand, String), TvBrandAdapter> _adapters;
  final VariantResolutionRegistry _variantRegistry;
  final LocalizedStrings _localizedStrings;
  final DeviceIdentityRegistry? _identityRegistry;

  @override
  Future<void> unpairDevice({required TvDevice device}) async {
    await _adapterFor(
      device.brand,
      device.protocolVariant,
    )?.unpairDevice(device: device);
  }

  @override
  Future<void> cancelPairing({required TvDevice device}) async {
    await _adapterFor(
      device.brand,
      device.protocolVariant,
    )?.cancelPairing(device: device);
  }

  @override
  Future<void> connect({required TvDevice device}) async {
    try {
      await _adapterFor(
        device.brand,
        device.protocolVariant,
      )?.connect(device: device);
    } catch (_) {
      // Background connect is best-effort. Connection state carries the
      // outcome; unhandled errors here are reported as Crashlytics crashes.
    }
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
        id: device.hasStableId ? device.id : (info?.stableId ?? device.id),
        capabilities: capabilities,
        protocolVariant: variant,
        modelIdentifier: info?.modelIdentifier,
      );
      _registerIdentity(enriched);
      if (capabilities.contains(DeviceCapability.pinPairing)) {
        // Handshake succeeded and the TV is now displaying a PIN.
        return CommandDispatchResult.pinRequired(
          _localizedStrings.pairingAndroidTvProgressHint,
          device: enriched,
          pinFormat: const TvCapabilities().pinFormatFor(device.brand, variant),
        );
      }
      return CommandDispatchResult.success(
        _localizedStrings.pairingApproved(device.displayName),
        device: enriched,
      );
    } on PinRequiredException catch (error) {
      // Adapter explicitly signalled that a PIN is required (e.g. Hisense).
      return CommandDispatchResult.pinRequired(
        error.message,
        pinFormat: const TvCapabilities().pinFormatFor(device.brand),
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
    required String pinCode,
  }) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter == null) {
      return CommandDispatchResult.unsupported(
        _localizedStrings.pairingNoAdapter(device.brand.name),
      );
    }
    try {
      await adapter.submitPairingCode(device: device, pinCode: pinCode);
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
        _localizedStrings.remoteCommandUnsupported(
          command.name,
          device.brand.name,
        ),
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
  Future<bool> checkRemoteTextInputReady({required TvDevice device}) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter == null) {
      return false;
    }
    if (!adapter.supportsTextInput) {
      return false;
    }
    if (!device.capabilities.contains(DeviceCapability.textInput)) {
      return false;
    }
    if (adapter is SamsungAdapter) {
      return adapter.probeRemoteTextInputReady(device: device);
    }
    if (adapter is LgAdapter) {
      return adapter.probeRemoteTextInputReady(device: device);
    }
    if (adapter is AndroidTvAdapter) {
      return adapter.probeRemoteTextInputReady(device: device);
    }
    try {
      return await adapter
          .watchRemoteTextInputReady(device)
          .first
          .timeout(const Duration(milliseconds: 750), onTimeout: () => false);
    } catch (_) {
      return false;
    }
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
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async {
    final adapter = _adapterFor(device.brand, device.protocolVariant);
    if (adapter == null) {
      return null;
    }
    return adapter.queryDeviceInfo(device: device);
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

  void _registerIdentity(TvDevice device) {
    final registry = _identityRegistry;
    if (registry == null) return;
    if (!device.hasStableId) return;
    final host = device.resolvedHost;
    if (host.isEmpty) return;
    registry.register(host, device.id);
  }
}
