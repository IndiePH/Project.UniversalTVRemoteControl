import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_remote/l10n/app_localizations.dart';

/// In-app feedback form: category, message, and send action.
class FeedbackSubmissionSheet extends StatefulWidget {
  const FeedbackSubmissionSheet({super.key, required this.onSubmit});

  final Future<FeedbackSheetSubmitOutcome> Function({
    required String message,
    required String category,
  })
  onSubmit;

  @override
  State<FeedbackSubmissionSheet> createState() =>
      _FeedbackSubmissionSheetState();
}

enum FeedbackSheetSubmitOutcome { success, empty, notConfigured, failed }

class _FeedbackSubmissionSheetState extends State<FeedbackSubmissionSheet> {
  static const int _minMessageLength = 10;
  static const int _maxMessageLength = 2000;

  final TextEditingController _controller = TextEditingController();
  String _category = 'suggestion';
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }
    setState(() => _isSending = true);
    try {
      final outcome = await widget.onSubmit(
        message: _controller.text,
        category: _category,
      );
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case FeedbackSheetSubmitOutcome.success:
          Navigator.of(context).pop(true);
        case FeedbackSheetSubmitOutcome.empty:
        case FeedbackSheetSubmitOutcome.notConfigured:
        case FeedbackSheetSubmitOutcome.failed:
          setState(() => _isSending = false);
      }
    } on Object {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  bool get _canSend {
    final length = _controller.text.trim().length;
    return !_isSending &&
        length >= _minMessageLength &&
        length <= _maxMessageLength;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.feedbackSheetTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.feedbackSheetSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'suggestion',
                      label: Text(l10n.feedbackCategorySuggestion),
                    ),
                    ButtonSegment(
                      value: 'bug',
                      label: Text(l10n.feedbackCategoryBug),
                    ),
                    ButtonSegment(
                      value: 'other',
                      label: Text(l10n.feedbackCategoryOther),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      setState(() => _category = selected.first);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: _maxMessageLength,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    hintText: l10n.feedbackMessageHint,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _canSend ? () => unawaited(_send()) : null,
                  child: _isSending
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.feedbackSendButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
