import 'package:flutter/material.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/l10n/app_localizations.dart';

/// User-facing settings and purchase actions for the remote home screen.
class RemoteHomeSettingsSheet extends StatelessWidget {
  const RemoteHomeSettingsSheet({
    super.key,
    required this.entitlementStatus,
    required this.storeAvailable,
    required this.onUpgradeToPro,
    required this.onRestorePurchases,
    required this.showDebugSection,
    required this.showTransportToggle,
    required this.useFakeTransports,
    required this.onUseFakeTransportsChanged,
    required this.onCopyTransportLogs,
    required this.onCopyRuntimeFlagsTemplate,
  });

  final ProEntitlementStatus entitlementStatus;
  final bool storeAvailable;
  final VoidCallback onUpgradeToPro;
  final VoidCallback onRestorePurchases;
  final bool showDebugSection;
  final bool showTransportToggle;
  final bool useFakeTransports;
  final Future<void> Function(bool value) onUseFakeTransportsChanged;
  final VoidCallback onCopyTransportLogs;
  final VoidCallback onCopyRuntimeFlagsTemplate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusText = switch (entitlementStatus) {
      ProEntitlementStatus.entitled => l10n.proStatusActive,
      ProEntitlementStatus.notEntitled => l10n.proStatusNotActive,
      ProEntitlementStatus.unknown => l10n.proStatusChecking,
    };
    final actionsDisabled =
        !storeAvailable || entitlementStatus == ProEntitlementStatus.unknown;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.settingsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.proSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(statusText),
              const SizedBox(height: 6),
              Text(
                l10n.proStoreAccountHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: actionsDisabled ? null : onUpgradeToPro,
                child: Text(l10n.proUpgradeButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: actionsDisabled ? null : onRestorePurchases,
                child: Text(l10n.proRestoreButton),
              ),
              if (!storeAvailable) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.proStoreUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (showDebugSection) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.settingsDebugSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (showTransportToggle) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsUseFakeTransportsTitle),
                    subtitle: SizedBox(
                      height: 40,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          useFakeTransports
                              ? l10n.settingsUseFakeTransportsEnabled
                              : l10n.settingsUseFakeTransportsDisabled,
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
                  title: Text(l10n.settingsCopyTransportLogs),
                  onTap: onCopyTransportLogs,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune),
                  title: Text(l10n.settingsCopyRuntimeFlagsTemplate),
                  subtitle: Text(l10n.settingsCopyRuntimeFlagsTemplateSubtitle),
                  onTap: onCopyRuntimeFlagsTemplate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
