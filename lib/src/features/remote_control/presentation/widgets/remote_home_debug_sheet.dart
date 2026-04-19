import 'package:flutter/material.dart';

/// Debug/settings content rendered inside the remote home bottom sheet.
class RemoteHomeDebugSheet extends StatelessWidget {
  const RemoteHomeDebugSheet({
    super.key,
    required this.showTransportToggle,
    required this.useFakeTransports,
    required this.compileTimeUseFakeTransports,
    required this.onUseFakeTransportsChanged,
    required this.onCopySamsungTextLogs,
  });

  final bool showTransportToggle;
  final bool useFakeTransports;
  final bool compileTimeUseFakeTransports;
  final Future<void> Function(bool value) onUseFakeTransportsChanged;
  final VoidCallback onCopySamsungTextLogs;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debug',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (showTransportToggle) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use fake transports'),
                subtitle: Text(
                  useFakeTransports
                      ? 'Fake SSDP and Samsung/Hisense transports.'
                      : 'Real SSDP and real Samsung/Hisense transports.',
                ),
                value: useFakeTransports,
                onChanged: (value) => onUseFakeTransportsChanged(value),
              ),
              Text(
                'Compile-time default: '
                '${compileTimeUseFakeTransports ? "fake" : "real"} '
                '(USE_FAKE_TRANSPORTS)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy),
              title: const Text('Copy Samsung text logs'),
              onTap: onCopySamsungTextLogs,
            ),
          ],
        ),
      ),
    );
  }
}
