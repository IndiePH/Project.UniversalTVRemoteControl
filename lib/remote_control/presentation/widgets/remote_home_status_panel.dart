import 'package:flutter/material.dart';

/// Header/status section shown above the remote layout canvas.
class RemoteHomeStatusPanel extends StatelessWidget {
  const RemoteHomeStatusPanel({
    super.key,
    required this.deviceName,
    required this.status,
    required this.child,
  });

  final String deviceName;
  final String status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          deviceName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(status),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}
