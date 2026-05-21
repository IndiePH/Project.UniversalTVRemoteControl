import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';

void main() {
  test('buildReport includes discovery rates and outcome buckets', () {
    final recorder = AppDiagnosticsRecorder();
    recorder.recordDiscoveryAttempt(deviceCount: 2);
    recorder.recordDiscoveryAttempt(deviceCount: 0);
    recorder.recordDiscoveryAttempt(deviceCount: 0, error: StateError('net'));
    recorder.recordPairingDispatch(
      phase: 'prepare',
      outcome: CommandOutcome.failure,
      brand: TvBrand.samsung,
    );
    recorder.recordPairingSession(brand: TvBrand.samsung, success: true);
    recorder.recordCommandDispatch(
      outcome: CommandOutcome.success,
      brand: TvBrand.samsung,
      action: 'power',
    );
    recorder.recordUnhandledError(Exception('boom'));

    final report = recorder.buildReport();
    expect(report, contains('attempts: 3'));
    expect(report, contains('with devices: 1'));
    expect(report, contains('empty: 1'));
    expect(report, contains('errors: 1'));
    expect(report, contains('prepare:failure:samsung'));
    expect(report, contains('power:success:samsung'));
    expect(report, contains('Unhandled errors: 1'));
    expect(report, contains('pairing session ok'));
  });
}
