import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:one_remote/app/ads/interstitial_ad_controller.dart';
import 'package:one_remote/l10n/app_localizations.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Dialog helpers for `PairingPage` destructive/confirmation flows.
final class PairingPageDialogs {
  const PairingPageDialogs._();

  static Future<bool> confirmPrePairing({
    required BuildContext context,
    required String brandName,
    required List<String> steps,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.pairingPreCheckTitle(brandName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pairingPreCheckMakeSure),
              const SizedBox(height: 8),
              ...steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.uiContinue),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  static Future<String?> promptPairingPin({
    required BuildContext context,
    required String pairingMessage,
    PinFormat pinFormat = PinFormat.fourDigitNumeric,
  }) async {
    final interstitial = _interstitialControllerOrNull();
    interstitial?.acquirePresentationBlock();
    final pinController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String? inputError;

          String? validatePin(AppLocalizations l10n) {
            final value = pinController.text.trim();
            return switch (pinFormat) {
              PinFormat.sixCharHex =>
                RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)
                    ? null
                    : l10n.pairingPinErrorInvalidHex,
              PinFormat.fourDigitNumeric =>
                RegExp(r'^\d{4}$').hasMatch(value)
                    ? null
                    : l10n.pairingPinErrorInvalid,
            };
          }

          void submit(StateSetter setDialogState, AppLocalizations l10n) {
            final error = validatePin(l10n);
            if (error != null) {
              setDialogState(() => inputError = error);
              return;
            }
            Navigator.of(context).pop(pinController.text.trim().toUpperCase());
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final l10n = AppLocalizations.of(context)!;
              final isHex = pinFormat == PinFormat.sixCharHex;
              return AlertDialog(
                title: Text(l10n.pairingPinTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.pairingPinBody),
                    const SizedBox(height: 8),
                    Text(
                      pairingMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      keyboardType: isHex
                          ? TextInputType.visiblePassword
                          : TextInputType.number,
                      maxLength: isHex ? 6 : 4,
                      autofocus: true,
                      textCapitalization: isHex
                          ? TextCapitalization.characters
                          : TextCapitalization.none,
                      decoration: InputDecoration(
                        labelText: isHex
                            ? l10n.pairingPinCodeLabelHex
                            : l10n.pairingPinCodeLabel,
                        border: const OutlineInputBorder(),
                        counterText: '',
                        errorText: inputError,
                      ),
                      onChanged: (_) {
                        if (inputError == null) return;
                        setDialogState(() => inputError = null);
                      },
                      onSubmitted: (_) => submit(setDialogState, l10n),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(l10n.uiCancel),
                  ),
                  FilledButton(
                    onPressed: () => submit(setDialogState, l10n),
                    child: Text(l10n.pairingPinSubmitButton),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      interstitial?.releasePresentationBlock();
    }
  }

  static InterstitialAdController? _interstitialControllerOrNull() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<InterstitialAdController>()) {
      return null;
    }
    return sl<InterstitialAdController>();
  }

  static Future<void> showPairingOutcome({
    required BuildContext context,
    required bool isSuccess,
    required String deviceName,
    String? errorMessage,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          icon: isSuccess
              ? Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                )
              : Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
          title: Text(
            isSuccess
                ? l10n.pairingOutcomeSuccessTitle
                : l10n.pairingOutcomeFailureTitle,
          ),
          content: Text(
            isSuccess
                ? l10n.pairingOutcomeSuccessBody(deviceName)
                : errorMessage ?? l10n.pairingExceptionFailed,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isSuccess ? l10n.uiDone : l10n.uiDismiss),
            ),
          ],
        );
      },
    );
  }

  static Future<String?> promptRenameDevice({
    required BuildContext context,
    required String currentName,
  }) {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) {
        String? inputError;

        void submit(StateSetter setDialogState, AppLocalizations l10n) {
          final name = controller.text.trim();
          if (name.isEmpty) {
            setDialogState(() => inputError = l10n.pairingRenameErrorEmpty);
            return;
          }
          Navigator.of(context).pop(name);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(l10n.pairingRenameDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.pairingRenameNameLabel,
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: inputError,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (inputError != null) {
                    setDialogState(() => inputError = null);
                  }
                },
                onSubmitted: (_) => submit(setDialogState, l10n),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(l10n.uiCancel),
                ),
                FilledButton(
                  onPressed: () => submit(setDialogState, l10n),
                  child: Text(l10n.uiRename),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<bool> confirmRemoveSavedDevice({
    required BuildContext context,
    required TvDevice device,
    required bool isActiveDevice,
  }) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final removeMessage = isActiveDevice
            ? l10n.pairingRemoveActiveBody
            : l10n.pairingRemoveSavedBody(device.displayName);
        return AlertDialog(
          title: Text(l10n.pairingRemoveTitle),
          content: Text(removeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.uiRemove),
            ),
          ],
        );
      },
    );

    return shouldRemove == true;
  }

  static Future<bool> confirmRemoveLegacyDevices({
    required BuildContext context,
    required List<TvDevice> devices,
  }) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.pairingLegacyCleanupTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pairingLegacyCleanupBody),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final device in devices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• ${device.displayName}'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pairingLegacyCleanupRemove),
            ),
          ],
        );
      },
    );

    return shouldRemove == true;
  }

  static Future<void> showDeviceInfo({
    required BuildContext context,
    required TvDevice device,
    required DateTime? pairedAt,
  }) async {
    final prefix = '${device.brand.name}-';
    final lastKnownIp = device.id.startsWith(prefix)
        ? device.id.substring(prefix.length)
        : null;

    final pairedAtLabel = pairedAt != null
        ? DateFormat.yMd().add_Hm().format(pairedAt.toLocal())
        : null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.pairingDeviceInfoTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: l10n.pairingDeviceInfoLabelName,
                value: device.displayName,
              ),
              _InfoRow(
                label: l10n.pairingDeviceInfoLabelBrand,
                value: device.brand.displayName,
              ),
              if (device.modelIdentifier != null)
                _InfoRow(
                  label: l10n.pairingDeviceInfoLabelModel,
                  value: device.modelIdentifier!,
                ),
              if (device.protocolVariant != TvDevice.defaultProtocolVariant)
                _InfoRow(
                  label: l10n.pairingDeviceInfoLabelVariant,
                  value: device.protocolVariant,
                ),
              if (pairedAtLabel != null)
                _InfoRow(
                  label: l10n.pairingDeviceInfoLabelPairedOn,
                  value: pairedAtLabel,
                ),
              if (lastKnownIp != null)
                _InfoRow(
                  label: l10n.pairingDeviceInfoLabelLastIp,
                  value: lastKnownIp,
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.uiDone),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
