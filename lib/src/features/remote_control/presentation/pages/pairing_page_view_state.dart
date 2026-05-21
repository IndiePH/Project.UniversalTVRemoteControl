import 'package:one_remote/src/features/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/src/features/remote_control/domain/models/tv_device.dart';

/// Local UI state for `PairingPage`.
final class PairingPageViewState {
  const PairingPageViewState({
    this.isLoading = false,
    this.isPairingInProgress = false,
    this.errorMessage,
    this.manualErrorMessage,
    this.manualBrand = TvBrand.samsung,
    this.savedDevices = const <TvDevice>[],
    this.discoveredDevices = const <TvDevice>[],
    this.recentManualIps = const <String>[],
    this.savedDeviceIds = const <String>{},
    this.pairingHistoryByDeviceId = const <String, DateTime>{},
  });

  final bool isLoading;
  final bool isPairingInProgress;
  final String? errorMessage;
  final String? manualErrorMessage;
  final TvBrand manualBrand;
  final List<TvDevice> savedDevices;
  final List<TvDevice> discoveredDevices;
  final List<String> recentManualIps;
  final Set<String> savedDeviceIds;
  final Map<String, DateTime> pairingHistoryByDeviceId;

  PairingPageViewState copyWith({
    bool? isLoading,
    bool? isPairingInProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? manualErrorMessage,
    bool clearManualErrorMessage = false,
    TvBrand? manualBrand,
    List<TvDevice>? savedDevices,
    List<TvDevice>? discoveredDevices,
    List<String>? recentManualIps,
    Set<String>? savedDeviceIds,
    Map<String, DateTime>? pairingHistoryByDeviceId,
  }) {
    return PairingPageViewState(
      isLoading: isLoading ?? this.isLoading,
      isPairingInProgress: isPairingInProgress ?? this.isPairingInProgress,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      manualErrorMessage: clearManualErrorMessage
          ? null
          : (manualErrorMessage ?? this.manualErrorMessage),
      manualBrand: manualBrand ?? this.manualBrand,
      savedDevices: savedDevices ?? this.savedDevices,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      recentManualIps: recentManualIps ?? this.recentManualIps,
      savedDeviceIds: savedDeviceIds ?? this.savedDeviceIds,
      pairingHistoryByDeviceId:
          pairingHistoryByDeviceId ?? this.pairingHistoryByDeviceId,
    );
  }
}
