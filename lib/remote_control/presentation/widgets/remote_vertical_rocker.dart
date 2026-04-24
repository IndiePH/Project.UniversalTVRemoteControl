import 'package:flutter/material.dart';
import 'package:one_remote/theme/app_theme.dart';

class RemoteVerticalRocker extends StatelessWidget {
  const RemoteVerticalRocker({
    super.key,
    required this.topText,
    required this.centerText,
    required this.bottomText,
    required this.onTopTap,
    required this.onBottomTap,
  });

  final String topText;
  final String centerText;
  final String bottomText;
  final VoidCallback onTopTap;
  final VoidCallback onBottomTap;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorsOf(context);
    final textStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );

    return Container(
      width: 78,
      height: 300,
      decoration: BoxDecoration(
        color: appColors.remoteSurface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: appColors.remoteOutline, width: 1.4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RockerTapArea(label: topText, onTap: onTopTap),
          Text(centerText, style: textStyle),
          _RockerTapArea(label: bottomText, onTap: onBottomTap),
        ],
      ),
    );
  }
}

class _RockerTapArea extends StatelessWidget {
  const _RockerTapArea({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
