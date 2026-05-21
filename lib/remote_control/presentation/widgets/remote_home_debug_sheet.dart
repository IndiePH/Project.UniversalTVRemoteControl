import 'package:flutter/material.dart';

/// Debug/settings content rendered inside the remote home bottom sheet.
class RemoteHomeDebugSheet extends StatelessWidget {
  const RemoteHomeDebugSheet({
    super.key,
    required this.showTransportToggle,
    required this.useFakeTransports,
    required this.onUseFakeTransportsChanged,
    required this.onCopyTransportLogs,
    required this.onCopyRuntimeFlagsTemplate,
  });

  final bool showTransportToggle;
  final bool useFakeTransports;
  final Future<void> Function(bool value) onUseFakeTransportsChanged;
  final VoidCallback onCopyTransportLogs;
  final VoidCallback onCopyRuntimeFlagsTemplate;

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
                subtitle: SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      useFakeTransports
                          ? 'Using fake discovery and fake transport clients.'
                          : 'Using real discovery and real transport clients.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                value: useFakeTransports,
                onChanged: (value) => onUseFakeTransportsChanged(value),
              ),
              const SizedBox(height: 8),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy),
              title: const Text('Copy transport logs'),
              onTap: onCopyTransportLogs,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: const Text('Copy runtime flags template'),
              subtitle: const Text('Paste and fill dart-define values.'),
              onTap: onCopyRuntimeFlagsTemplate,
            ),
          ],
        ),
      ),
    );
  }
}
