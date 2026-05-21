import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';

/// In-memory counters for internal troubleshooting (no network upload).
final class AppDiagnosticsRecorder {
  int discoveryAttempts = 0;
  int discoveryWithDevices = 0;
  int discoveryEmpty = 0;
  int discoveryErrors = 0;

  final Map<String, int> pairingOutcomeCounts = {};
  final Map<String, int> commandOutcomeCounts = {};
  int pairingSessionsSucceeded = 0;
  int pairingSessionsFailed = 0;
  int unhandledErrors = 0;

  static const int _maxRecentEvents = 30;
  final List<String> _recentEvents = [];

  void recordDiscoveryAttempt({
    required int deviceCount,
    Object? error,
  }) {
    discoveryAttempts++;
    if (error != null) {
      discoveryErrors++;
      _addEvent('discovery error: $error');
      return;
    }
    if (deviceCount == 0) {
      discoveryEmpty++;
      _addEvent('discovery empty');
      return;
    }
    discoveryWithDevices++;
    _addEvent('discovery ok ($deviceCount devices)');
  }

  void recordPairingDispatch({
    required String phase,
    required CommandOutcome outcome,
    required TvBrand brand,
  }) {
    final key = '$phase:${outcome.name}:${brand.name}';
    pairingOutcomeCounts[key] = (pairingOutcomeCounts[key] ?? 0) + 1;
    _addEvent('pairing $phase ${outcome.name} (${brand.name})');
  }

  void recordPairingSession({
    required TvBrand brand,
    required bool success,
  }) {
    if (success) {
      pairingSessionsSucceeded++;
      _addEvent('pairing session ok (${brand.name})');
    } else {
      pairingSessionsFailed++;
      _addEvent('pairing session failed (${brand.name})');
    }
  }

  void recordCommandDispatch({
    required CommandOutcome outcome,
    required TvBrand brand,
    required String action,
  }) {
    final key = '$action:${outcome.name}:${brand.name}';
    commandOutcomeCounts[key] = (commandOutcomeCounts[key] ?? 0) + 1;
    _addEvent('command $action ${outcome.name} (${brand.name})');
  }

  void recordUnhandledError(Object error) {
    unhandledErrors++;
    _addEvent('unhandled: $error');
  }

  String buildReport() {
    final buffer = StringBuffer('OneRemote diagnostics\n');
    buffer.writeln('generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Discovery');
    buffer.writeln('  attempts: $discoveryAttempts');
    buffer.writeln('  with devices: $discoveryWithDevices');
    buffer.writeln('  empty: $discoveryEmpty');
    buffer.writeln('  errors: $discoveryErrors');
    if (discoveryAttempts > 0) {
      final successRate =
          (discoveryWithDevices / discoveryAttempts * 100).toStringAsFixed(1);
      buffer.writeln('  success rate (found TV): $successRate%');
    }
    buffer.writeln();
    buffer.writeln('Pairing sessions');
    buffer.writeln('  succeeded: $pairingSessionsSucceeded');
    buffer.writeln('  failed: $pairingSessionsFailed');
    buffer.writeln();
    buffer.writeln('Pairing dispatch outcomes');
    _writeCountMap(buffer, pairingOutcomeCounts);
    buffer.writeln();
    buffer.writeln('Command dispatch outcomes');
    _writeCountMap(buffer, commandOutcomeCounts);
    buffer.writeln();
    buffer.writeln('Unhandled errors: $unhandledErrors');
    if (_recentEvents.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Recent events (newest last):');
      for (final event in _recentEvents) {
        buffer.writeln('  - $event');
      }
    }
    return buffer.toString();
  }

  void _writeCountMap(StringBuffer buffer, Map<String, int> counts) {
    if (counts.isEmpty) {
      buffer.writeln('  (none)');
      return;
    }
    final keys = counts.keys.toList()..sort();
    for (final key in keys) {
      buffer.writeln('  $key: ${counts[key]}');
    }
  }

  void _addEvent(String event) {
    _recentEvents.add(event);
    while (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeAt(0);
    }
  }
}
