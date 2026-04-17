import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_button.dart';

class RemoteDpad extends StatelessWidget {
  const RemoteDpad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onOk,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RemoteButton(label: 'Up', onPressed: onUp),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: RemoteButton(label: 'Left', onPressed: onLeft)),
            const SizedBox(width: 8),
            Expanded(
              child: RemoteButton(
                label: 'OK',
                onPressed: onOk,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: RemoteButton(label: 'Right', onPressed: onRight)),
          ],
        ),
        const SizedBox(height: 8),
        RemoteButton(label: 'Down', onPressed: onDown),
      ],
    );
  }
}
