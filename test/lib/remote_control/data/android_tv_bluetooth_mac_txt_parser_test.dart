import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/android_tv_bluetooth_mac_txt_parser.dart';

void main() {
  group('AndroidTvBluetoothMacTxtParser', () {
    test('extracts the bt value from a single-entry TXT record', () {
      expect(
        AndroidTvBluetoothMacTxtParser.parse('bt=AA:BB:CC:DD:EE:FF\n'),
        'aa:bb:cc:dd:ee:ff',
      );
    });

    test('lowercases the MAC for consistent id strings across scans', () {
      expect(
        AndroidTvBluetoothMacTxtParser.parse('bt=00:1A:2B:3C:4D:5E'),
        '00:1a:2b:3c:4d:5e',
      );
    });

    test('finds bt among multiple newline-joined TXT entries, in any order', () {
      expect(
        AndroidTvBluetoothMacTxtParser.parse(
          'id=abc123\nbt=AA:BB:CC:DD:EE:FF\nmodel=Chromecast\n',
        ),
        'aa:bb:cc:dd:ee:ff',
      );
      expect(
        AndroidTvBluetoothMacTxtParser.parse(
          'bt=AA:BB:CC:DD:EE:FF\nid=abc123\n',
        ),
        'aa:bb:cc:dd:ee:ff',
      );
    });

    test('returns null when no bt entry is present', () {
      expect(
        AndroidTvBluetoothMacTxtParser.parse('id=abc123\nmodel=Chromecast\n'),
        isNull,
      );
    });

    test('returns null for an empty TXT record', () {
      expect(AndroidTvBluetoothMacTxtParser.parse(''), isNull);
    });

    test('returns null when bt is present but has an empty value', () {
      expect(AndroidTvBluetoothMacTxtParser.parse('bt=\nid=abc123\n'), isNull);
    });

    test('ignores entries with no "=" separator instead of crashing', () {
      expect(
        AndroidTvBluetoothMacTxtParser.parse(
          'malformed-entry-no-equals\nbt=AA:BB:CC:DD:EE:FF\n',
        ),
        'aa:bb:cc:dd:ee:ff',
      );
    });

    test('trims surrounding whitespace around the key and value', () {
      expect(
        AndroidTvBluetoothMacTxtParser.parse(' bt = AA:BB:CC:DD:EE:FF \n'),
        'aa:bb:cc:dd:ee:ff',
      );
    });
  });
}
