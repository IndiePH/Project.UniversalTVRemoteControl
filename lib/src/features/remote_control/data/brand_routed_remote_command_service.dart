import 'package:one_remote/src/features/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/src/features/remote_control/application/remote_command_service.dart';
import 'package:one_remote/src/features/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/src/features/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

/// Routes generic remote actions to a brand-specific adapter.
///
/// Capability checks are enforced here so UI code can stay brand-agnostic.
class BrandRoutedRemoteCommandService implements RemoteCommandService {
  BrandRoutedRemoteCommandService({required List<TvBrandAdapter> adapters})
    : _adapters = {for (final adapter in adapters) adapter.brand: adapter};

  final Map<TvBrand, TvBrandAdapter> _adapters;

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
      return CommandDispatchResult.failure(
        'Failed to pair ${device.displayName}: $error',
      );
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
      return CommandDispatchResult.failure(
        'Failed to send ${command.name} for ${device.brand.name}: $error',
      );
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
    } catch (error) {
      return CommandDispatchResult.failure(
        'Failed to send text for ${device.brand.name}: $error',
      );
    }
  }

  TvBrandAdapter? _adapterFor(TvBrand brand) => _adapters[brand];
}
