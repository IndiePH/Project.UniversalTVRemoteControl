import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart'
    as remote_connection;
import 'package:one_remote/remote_control/presentation/widgets/connection_state_presentation.dart';

/// Compact connection indicator (dot or wifi icon) derived from transport state.
class TvConnectionStateIndicator extends StatelessWidget {
  const TvConnectionStateIndicator({
    super.key,
    required this.state,
    this.style = TvConnectionStateIndicatorStyle.compactIcon,
    this.iconSize = 18,
    this.dotSize = 10,
  });

  final remote_connection.ConnectionState state;
  final TvConnectionStateIndicatorStyle style;
  final double iconSize;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final presentation = connectionStatePresentation(
      context: context,
      state: state,
    );
    return switch (style) {
      TvConnectionStateIndicatorStyle.compactIcon => Icon(
        connectionStateIcon(state),
        size: iconSize,
        color: presentation.color,
      ),
      TvConnectionStateIndicatorStyle.statusDot => Icon(
        Icons.circle,
        size: dotSize,
        color: presentation.color,
      ),
      TvConnectionStateIndicatorStyle.labeledRow => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: dotSize, color: presentation.color),
          const SizedBox(width: 8),
          Text(presentation.label),
        ],
      ),
    };
  }
}

enum TvConnectionStateIndicatorStyle { compactIcon, statusDot, labeledRow }
