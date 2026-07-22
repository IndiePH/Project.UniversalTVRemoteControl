import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/application/tv_reachability_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

class AdapterTvReachabilityService implements TvReachabilityService {
  AdapterTvReachabilityService({required this._adapters});

  final List<TvBrandAdapter> _adapters;

  @override
  Future<bool> isReachable(TvDevice device) async {
    final adapter = _resolveAdapter(device);
    if (adapter == null) return false;
    try {
      await adapter.probeConnection(device: device);
      return true;
    } catch (_) {
      return false;
    }
  }

  TvBrandAdapter? _resolveAdapter(TvDevice device) {
    TvBrandAdapter? brandMatch;
    for (final adapter in _adapters) {
      if (adapter.brand == device.brand) {
        if (adapter.protocolVariant == device.protocolVariant) return adapter;
        brandMatch ??= adapter;
      }
    }
    return brandMatch;
  }
}
