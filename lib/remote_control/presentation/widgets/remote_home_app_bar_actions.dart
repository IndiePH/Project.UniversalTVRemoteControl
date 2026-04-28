import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onToggleLayoutEditMode,
          icon: Icon(isLayoutEditMode ? Icons.check : Icons.edit_outlined),
          tooltip: isLayoutEditMode ? l10n.layoutEditDoneTooltip : l10n.layoutEditTooltip,
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
