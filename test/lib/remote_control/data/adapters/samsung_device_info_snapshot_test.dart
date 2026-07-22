import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_device_info_snapshot.dart';

void main() {
  group('SamsungDeviceInfoSnapshot', () {
    test('fromConnectData maps ms.channel.connect fields', () {
      final snapshot = SamsungDeviceInfoSnapshot.fromConnectData({
        'model': 'UE55',
        'OS': 'Tizen 7.0',
        'firmwareVersion': '2901.1',
        'version': '2.0.25',
        'id': 'abc',
      });
      expect(snapshot, isNotNull);
      final info = snapshot!.toTvDeviceInfo();
      expect(info.modelIdentifier, 'UE55');
      expect(info.firmwareVersion, '2901.1');
      expect(info.debugDetails, contains('OS: Tizen 7.0'));
      expect(info.debugDetails, contains('Frame: 2.0.25'));
      expect(info.debugDetails, contains('Id: abc'));
    });

    test('fromConnectData returns null when payload empty', () {
      expect(SamsungDeviceInfoSnapshot.fromConnectData({}), isNull);
    });
  });
}
