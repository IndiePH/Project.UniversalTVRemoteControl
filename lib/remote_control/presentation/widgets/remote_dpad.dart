import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_button.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        RemoteButton(label: l10n.dpadUp, onPressed: onUp),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RemoteButton(label: l10n.dpadLeft, onPressed: onLeft),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RemoteButton(
                label: l10n.dpadOk,
                onPressed: onOk,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RemoteButton(label: l10n.dpadRight, onPressed: onRight),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RemoteButton(label: l10n.dpadDown, onPressed: onDown),
      ],
    );
  }
}
