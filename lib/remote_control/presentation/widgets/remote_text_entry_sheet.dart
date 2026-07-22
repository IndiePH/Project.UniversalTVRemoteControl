import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';

/// Bottom-sheet content for sending text to the active TV session.
class RemoteTextEntrySheet extends StatelessWidget {
  const RemoteTextEntrySheet({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.remoteTextEntrySheetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.remoteTextEntryHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => unawaited(onSend()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(onSend()),
                child: Text(l10n.remoteTextEntrySendButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
