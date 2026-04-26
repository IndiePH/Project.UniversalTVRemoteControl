import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Local UI state for `PairingPage`.
final class PairingPageViewState {
  const PairingPageViewState({
    this.isLoading = false,
    this.isPairingInProgress = false,
    this.pairingHint,
    this.errorMessage,
    this.savedDevices = const <TvDevice>[],
    this.discoveredDevices = const <TvDevice>[],
    this.recentManualIps = const <String>[],
    this.savedDeviceIds = const <String>{},
    this.pairingHistoryByDeviceId = const <String, DateTime>{},
    this.scanCount = 0,
  });

  final bool isLoading;
  final bool isPairingInProgress;
  /// Contextual hint shown inside the busy overlay (e.g. "Check your TV screen").
  final String? pairingHint;
  final String? errorMessage;
  final List<TvDevice> savedDevices;
  final List<TvDevice> discoveredDevices;
  final List<String> recentManualIps;
  final Set<String> savedDeviceIds;
  final Map<String, DateTime> pairingHistoryByDeviceId;
  /// Incremented on each scan; used as a key seed to force reachability re-probe.
  final int scanCount;

  PairingPageViewState copyWith({
    bool? isLoading,
    bool? isPairingInProgress,
    String? pairingHint,
    bool clearPairingHint = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<TvDevice>? savedDevices,
    List<TvDevice>? discoveredDevices,
    List<String>? recentManualIps,
    Set<String>? savedDeviceIds,
    Map<String, DateTime>? pairingHistoryByDeviceId,
    int? scanCount,
  }) {
    return PairingPageViewState(
      isLoading: isLoading ?? this.isLoading,
      isPairingInProgress: isPairingInProgress ?? this.isPairingInProgress,
      pairingHint: clearPairingHint ? null : (pairingHint ?? this.pairingHint),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      savedDevices: savedDevices ?? this.savedDevices,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      recentManualIps: recentManualIps ?? this.recentManualIps,
      savedDeviceIds: savedDeviceIds ?? this.savedDeviceIds,
      pairingHistoryByDeviceId:
          pairingHistoryByDeviceId ?? this.pairingHistoryByDeviceId,
      scanCount: scanCount ?? this.scanCount,
    );
  }
}
