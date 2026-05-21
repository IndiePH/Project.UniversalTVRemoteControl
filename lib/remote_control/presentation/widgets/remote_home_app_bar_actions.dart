import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';

/// App bar actions for `RemoteHomePage`.
class RemoteHomeAppBarActions extends StatelessWidget {
  const RemoteHomeAppBarActions({
    super.key,
    required this.isLayoutEditMode,
    required this.onToggleLayoutEditMode,
    required this.onShowSettings,
    required this.isPro,
  });

  final bool isLayoutEditMode;
  final VoidCallback? onToggleLayoutEditMode;
  final VoidCallback onShowSettings;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onToggleLayoutEditMode,
          icon: Icon(
            isLayoutEditMode
                ? Icons.check
                : (isPro
                      ? Icons.edit_outlined
                      : Icons.workspace_premium_outlined),
          ),
          tooltip: isLayoutEditMode
              ? l10n.layoutEditDoneTooltip
              : (isPro ? l10n.layoutEditTooltip : l10n.proLayoutLockedTooltip),
        ),
        IconButton(
          onPressed: onShowSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.settingsTooltip,
        ),
      ],
    );
  }
}
