import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Dialog helpers for `PairingPage` destructive/confirmation flows.
final class PairingPageDialogs {
  const PairingPageDialogs._();

  static Future<String?> promptHisensePairingPin({
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
                    'Hisense TV may require a 4-digit code shown on-screen to finish pairing.',
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
