import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/ssdp_brand_inference.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';

void main() {
  group('inferSsdpTvBrand', () {
    test('identifies Samsung from server header', () {
      expect(
        inferSsdpTvBrand({'server': 'Samsung-Linux/3.14 UPnP/1.0'}),
        TvBrand.samsung,
      );
    });

    test('identifies LG from webOS fingerprint', () {
      expect(
        inferSsdpTvBrand({'server': 'webos/6.0 upnp/1.1'}),
        TvBrand.lg,
      );
    });

    test('identifies Hisense from vidaa hint', () {
      expect(
        inferSsdpTvBrand({'usn': 'uuid:device-VIDAA-123'}),
        TvBrand.hisense,
      );
    });

    test('prefers Roku when roku appears in probe', () {
      expect(
        inferSsdpTvBrand({'server': 'roku:ecp'}),
        TvBrand.roku,
      );
    });

    test('returns null for unrelated UPnP devices', () {
      expect(
        inferSsdpTvBrand({'server': 'Linux/3.0 UPnP/1.0 Philips'}),
        isNull,
      );
    });
  });
}
