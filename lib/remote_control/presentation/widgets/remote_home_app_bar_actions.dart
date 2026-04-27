import 'package:flutter/material.dart';

/// App bar actions for `RemoteHomePage`.
class RemoteHomeAppBarActions extends StatelessWidget {
  const RemoteHomeAppBarActions({
    super.key,
    required this.isLayoutEditMode,
    required this.onToggleLayoutEditMode,
    required this.onShowDebugSettings,
  });

  final bool isLayoutEditMode;
  final VoidCallback? onToggleLayoutEditMode;
  final VoidCallback onShowDebugSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onToggleLayoutEditMode,
          icon: Icon(isLayoutEditMode ? Icons.check : Icons.edit_outlined),
          tooltip: isLayoutEditMode ? 'Done editing layout' : 'Edit layout',
        ),
        IconButton(
          onPressed: onShowDebugSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Debug settings',
        ),
      ],
    );
  }
}
