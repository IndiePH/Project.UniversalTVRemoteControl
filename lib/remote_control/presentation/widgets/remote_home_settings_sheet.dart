import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/app/theme/app_theme_preference.dart';
import 'package:one_remote/app/monetization/pro_entitlement_status.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';
import 'package:one_remote/remote_control/presentation/widgets/diagnostics_summary_panel.dart';
import 'package:one_remote/remote_control/presentation/widgets/tv_device_debug_info_panel.dart';

/// User-facing settings and purchase actions for the remote home screen.
class RemoteHomeSettingsSheet extends StatelessWidget {
  const RemoteHomeSettingsSheet({
    super.key,
    required this.entitlementStatus,
    required this.storeAvailable,
    required this.onUpgradeToPro,
    required this.onRestorePurchases,
    required this.showDebugSection,
    required this.activeDevice,
    required this.queryDeviceInfo,
    required this.showTransportToggle,
    required this.useFakeTransports,
    required this.onUseFakeTransportsChanged,
    required this.onCopyTransportLogs,
    required this.onCopyDiagnosticsReport,
    required this.diagnosticsRecorder,
    required this.onCopyRuntimeFlagsTemplate,
    required this.onOpenFeedback,
    required this.onOpenOpenSourceLicenses,
    required this.showPrivacyPolicyLink,
    required this.onOpenPrivacyPolicy,
    required this.showAdPrivacyOptions,
    required this.onOpenAdPrivacyOptions,
    required this.themePreference,
    required this.onThemePreferenceChanged,
  });

  final ProEntitlementStatus entitlementStatus;
  final bool storeAvailable;
  final VoidCallback onUpgradeToPro;
  final VoidCallback onRestorePurchases;
  final bool showDebugSection;
  final TvDevice? activeDevice;
  final Future<TvDeviceInfo?> Function({required TvDevice device})
      queryDeviceInfo;
  final bool showTransportToggle;
  final bool useFakeTransports;
  final Future<void> Function(bool value) onUseFakeTransportsChanged;
  final VoidCallback onCopyTransportLogs;
  final VoidCallback onCopyDiagnosticsReport;
  final AppDiagnosticsRecorder diagnosticsRecorder;
  final VoidCallback onCopyRuntimeFlagsTemplate;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenOpenSourceLicenses;
  final bool showPrivacyPolicyLink;
  final VoidCallback onOpenPrivacyPolicy;
  final bool showAdPrivacyOptions;
  final VoidCallback onOpenAdPrivacyOptions;
  final AppThemePreference themePreference;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;

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
    final isEntitled = entitlementStatus == ProEntitlementStatus.entitled;
    final storeAccountHint = switch (defaultTargetPlatform) {
      TargetPlatform.android => l10n.proStoreAccountHintGooglePlay,
      TargetPlatform.iOS => l10n.proStoreAccountHintAppStore,
      _ => l10n.proStoreAccountHintGooglePlay,
    };

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
                l10n.settingsAppearanceSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AppThemePreference>(
                segments: [
                  ButtonSegment(
                    value: AppThemePreference.light,
                    label: Text(l10n.settingsThemeLight),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.dark,
                    label: Text(l10n.settingsThemeDark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.system,
                    label: Text(l10n.settingsThemeSystem),
                    icon: const Icon(Icons.brightness_auto_outlined),
                  ),
                ],
                selected: {themePreference},
                onSelectionChanged: (selected) {
                  if (selected.isNotEmpty) {
                    onThemePreferenceChanged(selected.first);
                  }
                },
              ),
              if (themePreference == AppThemePreference.system) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.settingsThemeSystemSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.proSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(statusText),
              const SizedBox(height: 6),
              Text(
                storeAccountHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (!isEntitled) ...[
                FilledButton(
                  onPressed: actionsDisabled ? null : onUpgradeToPro,
                  child: Text(l10n.proUpgradeButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: actionsDisabled ? null : onRestorePurchases,
                  child: Text(l10n.proRestoreButton),
                ),
              ],
              if (!storeAvailable) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.proStoreUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.settingsFeedbackSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.settingsFeedbackHelper,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rate_review_outlined),
                title: Text(l10n.settingsSendFeedback),
                onTap: onOpenFeedback,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.settingsLegalSectionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.settingsOpenSourceLicenses),
                onTap: onOpenOpenSourceLicenses,
              ),
              if (showPrivacyPolicyLink || showAdPrivacyOptions) ...[
                if (showPrivacyPolicyLink)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(l10n.settingsPrivacyPolicy),
                    onTap: onOpenPrivacyPolicy,
                  ),
                if (showAdPrivacyOptions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.ads_click_outlined),
                    title: Text(l10n.settingsAdPrivacyOptions),
                    onTap: onOpenAdPrivacyOptions,
                  ),
              ],
              if (showDebugSection) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.settingsDebugSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DiagnosticsSummaryPanel(recorder: diagnosticsRecorder),
                const SizedBox(height: 8),
                TvDeviceDebugInfoPanel(
                  device: activeDevice,
                  infoFuture: queryDeviceInfo,
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
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text(l10n.settingsCopyDiagnosticsReport),
                  onTap: onCopyDiagnosticsReport,
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
