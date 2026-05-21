import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/discovery_result_merger.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

TvDevice _device({
  required String id,
  required TvBrand brand,
  required String displayName,
}) {
  return TvDevice(
    id: id,
    displayName: displayName,
    brand: brand,
    capabilities: const TvCapabilities().capabilitiesFor(brand),
  );
}

void main() {
  group('DiscoveryResultMerger.mergeByHost', () {
    test('keeps higher-priority brand when same IP is discovered twice', () {
      const ip = '192.168.1.50';
      final merged = DiscoveryResultMerger.mergeByHost([
        _device(
          id: 'androidtv-$ip',
          brand: TvBrand.androidTv,
          displayName: 'Living Room',
        ),
        _device(
          id: 'samsung-$ip',
          brand: TvBrand.samsung,
          displayName: 'Samsung TV ($ip)',
        ),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.brand, TvBrand.samsung);
    });

    test('orders full-support brands before experimental', () {
      final merged = DiscoveryResultMerger.mergeByHost([
        _device(
          id: 'androidtv-192.168.1.2',
          brand: TvBrand.androidTv,
          displayName: 'Z Stick',
        ),
        _device(
          id: 'lg-192.168.1.3',
          brand: TvBrand.lg,
          displayName: 'A LG TV',
        ),
      ]);

      expect(merged.first.brand, TvBrand.lg);
    });
  });
}
