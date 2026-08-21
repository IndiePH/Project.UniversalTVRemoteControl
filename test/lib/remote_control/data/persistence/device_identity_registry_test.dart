import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';

void main() {
  group('DeviceIdentityRegistry', () {
    test('register binds host to stableId and resolves via stableIdForHost',
        () {
      final registry = DeviceIdentityRegistry();
      registry.register('192.168.1.10', 'samsung-uuid-1');

      expect(registry.stableIdForHost('192.168.1.10'), 'samsung-uuid-1');
    });

    test('stableIdForHost is case- and whitespace-insensitive on host', () {
      final registry = DeviceIdentityRegistry();
      registry.register('  192.168.1.10  ', 'samsung-uuid-1');

      expect(registry.stableIdForHost('192.168.1.10'), 'samsung-uuid-1');
    });

    test('re-registering a host overwrites the previous stableId binding', () {
      final registry = DeviceIdentityRegistry();
      registry.register('192.168.1.10', 'samsung-uuid-1');
      registry.register('192.168.1.10', 'samsung-uuid-2');

      expect(registry.stableIdForHost('192.168.1.10'), 'samsung-uuid-2');
    });

    test('stableIdForHost returns null for an unmapped host', () {
      final registry = DeviceIdentityRegistry();
      expect(registry.stableIdForHost('192.168.1.99'), isNull);
    });

    test('forgetHost removes only that host binding', () {
      final registry = DeviceIdentityRegistry();
      registry.register('192.168.1.10', 'samsung-uuid-1');
      registry.register('192.168.1.11', 'samsung-uuid-1');

      registry.forgetHost('192.168.1.10');

      expect(registry.stableIdForHost('192.168.1.10'), isNull);
      expect(registry.stableIdForHost('192.168.1.11'), 'samsung-uuid-1');
    });

    test('forgetStableId removes every host bound to that stableId', () {
      final registry = DeviceIdentityRegistry();
      registry.register('192.168.1.10', 'samsung-uuid-1');
      registry.register('192.168.1.11', 'samsung-uuid-1');
      registry.register('192.168.1.12', 'samsung-uuid-2');

      registry.forgetStableId('samsung-uuid-1');

      expect(registry.stableIdForHost('192.168.1.10'), isNull);
      expect(registry.stableIdForHost('192.168.1.11'), isNull);
      expect(registry.stableIdForHost('192.168.1.12'), 'samsung-uuid-2');
    });

    test('register ignores empty host or stableId', () {
      final registry = DeviceIdentityRegistry();
      registry.register('', 'samsung-uuid-1');
      registry.register('192.168.1.10', '');

      expect(registry.stableIdForHost('192.168.1.10'), isNull);
    });
  });

  group('DeviceIdentityRegistry reverse lookup', () {
    test('hostForStableId returns the registered host', () {
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.10', 'samsung-uuid-1');

      expect(registry.hostForStableId('samsung-uuid-1'), '192.168.1.10');
    });

    test('hostForStableId returns the most recently registered host', () {
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.10', 'samsung-uuid-1')
        ..register('192.168.1.42', 'samsung-uuid-1');

      expect(registry.hostForStableId('samsung-uuid-1'), '192.168.1.42');
    });

    test('hostForStableId returns null for an unknown stableId', () {
      final registry = DeviceIdentityRegistry();
      expect(registry.hostForStableId('samsung-uuid-9'), isNull);
    });

    test('forgetHost updates the reverse lookup to another known host', () {
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.10', 'samsung-uuid-1')
        ..register('192.168.1.42', 'samsung-uuid-1');

      registry.forgetHost('192.168.1.42');

      expect(registry.hostForStableId('samsung-uuid-1'), '192.168.1.10');
    });
  });
}
