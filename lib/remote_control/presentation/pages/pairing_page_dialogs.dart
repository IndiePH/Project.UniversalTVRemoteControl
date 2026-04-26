import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/utils/two_digit_format.dart';

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
      builder: (context) => AlertDialog(
        title: Text('Before pairing with $brandName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Make sure:'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<String?> promptPairingPin({
    required BuildContext context,
    required String pairingMessage,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? inputError;

        String? validatePin() {
          final value = controller.text.trim();
          if (!RegExp(r'^\d{4}$').hasMatch(value)) {
            return 'Enter exactly 4 digits.';
          }
          return null;
        }

        void submit(StateSetter setDialogState) {
          final error = validatePin();
          if (error != null) {
            setDialogState(() {
              inputError = error;
            });
            return;
          }
          Navigator.of(context).pop(controller.text.trim());
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter TV pairing code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your TV may require a 4-digit code shown on-screen to finish pairing.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pairingMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '4-digit TV code',
                      border: const OutlineInputBorder(),
                      counterText: '',
                      errorText: inputError,
                    ),
                    onChanged: (_) {
                      if (inputError == null) {
                        return;
                      }
                      setDialogState(() {
                        inputError = null;
                      });
                    },
                    onSubmitted: (_) => submit(setDialogState),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => submit(setDialogState),
                  child: const Text('Submit code'),
                ),
              ],
            );
          },
        );
      },
    );
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
      builder: (context) => AlertDialog(
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
        title: Text(isSuccess ? 'Paired successfully' : 'Pairing failed'),
        content: Text(
          isSuccess
              ? '$deviceName is ready to use.'
              : errorMessage ?? 'Pairing failed. Please try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isSuccess ? 'Done' : 'Dismiss'),
          ),
        ],
      ),
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

        void submit(StateSetter setDialogState) {
          final name = controller.text.trim();
          if (name.isEmpty) {
            setDialogState(() => inputError = 'Enter a name.');
            return;
          }
          Navigator.of(context).pop(name);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Rename TV'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'TV name',
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: inputError,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (inputError != null) setDialogState(() => inputError = null);
              },
              onSubmitted: (_) => submit(setDialogState),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => submit(setDialogState),
                child: const Text('Rename'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool> confirmRemoveSavedDevice({
    required BuildContext context,
    required TvDevice device,
    required bool isActiveDevice,
  }) async {
    final removeMessage = isActiveDevice
        ? 'This is the currently connected device. Removing it may disconnect your current control session.'
        : 'This will remove "${device.displayName}" from saved devices.';

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove saved device?'),
          content: Text(removeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
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

    String? pairedAtLabel;
    if (pairedAt != null) {
      final local = pairedAt.toLocal();
      pairedAtLabel =
          '${local.year}-${formatTwoDigits(local.month)}-${formatTwoDigits(local.day)}'
          ' ${formatTwoDigits(local.hour)}:${formatTwoDigits(local.minute)}';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Name', value: device.displayName),
            _InfoRow(label: 'Brand', value: device.brand.displayName),
            if (device.modelIdentifier != null)
              _InfoRow(label: 'Model', value: device.modelIdentifier!),
            if (device.protocolVariant != TvDevice.defaultProtocolVariant)
              _InfoRow(label: 'Variant', value: device.protocolVariant),
            if (pairedAtLabel != null)
              _InfoRow(label: 'Paired on', value: pairedAtLabel),
            if (lastKnownIp != null)
              _InfoRow(label: 'Last known IP', value: lastKnownIp),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static Future<bool> confirmActiveRemoval({
    required BuildContext context,
  }) async {
    const expectedText = 'REMOVE';
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? inputError;

        bool isValidInput() {
          return controller.text.trim().toUpperCase() == expectedText;
        }

        void trySubmit(StateSetter setDialogState) {
          if (isValidInput()) {
            Navigator.of(context).pop(true);
            return;
          }
          setDialogState(() {
            inputError = 'Type REMOVE exactly to confirm.';
          });
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm active device removal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'To continue, type REMOVE. This helps prevent accidental disconnects.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Type REMOVE',
                      border: const OutlineInputBorder(),
                      errorText: inputError,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (inputError == null) {
                        return;
                      }
                      setDialogState(() {
                        inputError = null;
                      });
                    },
                    onSubmitted: (_) => trySubmit(setDialogState),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => trySubmit(setDialogState),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true;
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
