import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';

void main() {
  test('transient connection loss should auto-reconnect', () {
    expect(ConnectionState.disconnected.shouldAutoReconnect, isTrue);
    expect(ConnectionState.error.shouldAutoReconnect, isTrue);
  });

  test('TV authorization denial should not auto-reconnect', () {
    expect(ConnectionState.unauthorized.shouldAutoReconnect, isFalse);
    expect(ConnectionState.connected.shouldAutoReconnect, isFalse);
    expect(ConnectionState.connecting.shouldAutoReconnect, isFalse);
  });
}
