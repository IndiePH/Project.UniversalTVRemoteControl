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

    test('dedups by explicit host when set, ignoring the id', () {
      // Two discovery hits for the same physical device: one carries a
      // stable id (no IP) with an explicit host, the other an IP-derived id.
      // They must merge because resolvedHost resolves to the same IP.
      final merged = DiscoveryResultMerger.mergeByHost([
        TvDevice(
          id: 'samsung-uuid:1234',
          displayName: 'Samsung TV (192.168.1.50)',
          brand: TvBrand.samsung,
          capabilities: const TvCapabilities().capabilitiesFor(TvBrand.samsung),
          host: '192.168.1.50',
        ),
        _device(
          id: 'samsung-192.168.1.50',
          brand: TvBrand.samsung,
          displayName: 'Samsung TV (192.168.1.50)',
        ),
      ]);

      expect(merged, hasLength(1));
    });

    test('falls back to id for dedup when host is empty and id has no IP', () {
      // Devices with neither an explicit host nor an IP in their id must not
      // all collapse into one empty-string bucket; they dedup by their ids.
      final merged = DiscoveryResultMerger.mergeByHost([
        TvDevice(
          id: 'roku-YX001',
          displayName: 'Roku A',
          brand: TvBrand.roku,
          capabilities: const TvCapabilities().capabilitiesFor(TvBrand.roku),
        ),
        TvDevice(
          id: 'roku-YX002',
          displayName: 'Roku B',
          brand: TvBrand.roku,
          capabilities: const TvCapabilities().capabilitiesFor(TvBrand.roku),
        ),
      ]);

      expect(merged, hasLength(2));
    });
  });
}
