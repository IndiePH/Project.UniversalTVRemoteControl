import 'dart:async';

import 'package:flutter/material.dart';

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send text to TV',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search or enter text',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => unawaited(onSend()),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(onSend()),
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
