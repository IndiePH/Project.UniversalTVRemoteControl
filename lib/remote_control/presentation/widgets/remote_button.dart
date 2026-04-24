import 'package:flutter/material.dart';

class RemoteButton extends StatelessWidget {
  const RemoteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        backgroundColor ?? (isPrimary ? colorScheme.primary : colorScheme.surface);
    final foreground =
        foregroundColor ?? (isPrimary ? colorScheme.onPrimary : colorScheme.onSurface);
    final buttonChild = icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
        ),
        onPressed: onPressed,
        child: buttonChild,
      ),
    );
  }
}
