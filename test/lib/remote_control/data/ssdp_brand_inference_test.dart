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
      expect(inferSsdpTvBrand({'server': 'webos/6.0 upnp/1.1'}), TvBrand.lg);
    });

    test('identifies Hisense from vidaa hint in usn', () {
      expect(
        inferSsdpTvBrand({'usn': 'uuid:device-VIDAA-123'}),
        TvBrand.hisense,
      );
    });

    test('identifies Hisense from hisense in server header', () {
      expect(
        inferSsdpTvBrand({'server': 'hisense upnp/1.0 linux/3.14'}),
        TvBrand.hisense,
      );
    });

    test('identifies Hisense from hiview in nt when hisense/vidaa absent', () {
      expect(
        inferSsdpTvBrand({
          'nt': 'urn:schemas-upnp-org:device:hiviewmediarenderer:1',
        }),
        TvBrand.hisense,
      );
    });

    test('ssdpDiscoveryProbeText includes nt for Hisense fingerprinting', () {
      final probe = ssdpDiscoveryProbeText({
        'nt': 'urn:device:hiview:1',
        'server': 'linux upnp/1.0',
      });
      expect(probe.toLowerCase(), contains('hiview'));
      expect(inferSsdpTvBrand({'nt': 'urn:device:hiview:1'}), TvBrand.hisense);
    });

    test('prefers Roku when roku appears in probe', () {
      expect(inferSsdpTvBrand({'server': 'roku:ecp'}), TvBrand.roku);
    });

    test('returns null for unrelated UPnP devices', () {
      expect(
        inferSsdpTvBrand({'server': 'Linux/3.0 UPnP/1.0 Philips'}),
        isNull,
      );
    });
  });

  group('udnFromSsdpHeaders', () {
    test('extracts the UUID from a rootdevice USN', () {
      expect(
        udnFromSsdpHeaders({
          'usn': 'uuid:12345678-1234-1234-1234-123456789abc::upnp:rootdevice',
        }),
        '12345678-1234-1234-1234-123456789abc',
      );
    });

    test('extracts the UUID from a bare uuid USN', () {
      expect(
        udnFromSsdpHeaders({
          'usn': 'uuid:abcdef12-3456-7890-abcd-ef1234567890',
        }),
        'abcdef12-3456-7890-abcd-ef1234567890',
      );
    });

    test('extracts the UUID from a service USN', () {
      expect(
        udnFromSsdpHeaders({
          'usn':
              'uuid:11111111-2222-3333-4444-555555555555::urn:schemas-upnp-org:device:MediaRenderer:1',
        }),
        '11111111-2222-3333-4444-555555555555',
      );
    });

    test('returns null when USN is absent', () {
      expect(udnFromSsdpHeaders({}), isNull);
    });

    test('returns null when USN has no uuid token', () {
      expect(udnFromSsdpHeaders({'usn': 'upnp:rootdevice'}), isNull);
    });

    test('returns null for a malformed UUID', () {
      expect(udnFromSsdpHeaders({'usn': 'uuid:not-a-uuid'}), isNull);
    });
  });
}
