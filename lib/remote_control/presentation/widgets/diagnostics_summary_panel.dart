import 'package:flutter/material.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/l10n/app_localizations.dart';

/// Compact diagnostics counters for the debug settings section.
class DiagnosticsSummaryPanel extends StatelessWidget {
  const DiagnosticsSummaryPanel({super.key, required this.recorder});

  final AppDiagnosticsRecorder recorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final discoveryRate = recorder.discoveryAttempts == 0
        ? '—'
        : '${(recorder.discoveryWithDevices / recorder.discoveryAttempts * 100).toStringAsFixed(0)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsDiagnosticsSummaryTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.settingsDiagnosticsDiscoveryLine(
            recorder.discoveryAttempts,
            discoveryRate,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          l10n.settingsDiagnosticsPairingLine(
            recorder.pairingSessionsSucceeded,
            recorder.pairingSessionsFailed,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          l10n.settingsDiagnosticsUnhandledLine(recorder.unhandledErrors),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
