import 'package:flutter/material.dart';
import 'package:one_remote/src/theme/app_theme.dart';

class RemoteCircularDpad extends StatelessWidget {
  const RemoteCircularDpad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onOk,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorsOf(context);
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appColors.remoteSurface,
              border: Border.all(color: appColors.remoteOutline, width: 1.4),
            ),
          ),
          _ArrowButton(
            alignment: Alignment.topCenter,
            icon: Icons.keyboard_arrow_up,
            iconPadding: const EdgeInsets.only(bottom: 16),
            onTap: onUp,
            iconColor: appColors.remoteGlyphOnRemote,
          ),
          _ArrowButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.keyboard_arrow_down,
            iconPadding: const EdgeInsets.only(top: 16),
            onTap: onDown,
            iconColor: appColors.remoteGlyphOnRemote,
          ),
          _ArrowButton(
            alignment: Alignment.centerLeft,
            icon: Icons.keyboard_arrow_left,
            iconPadding: const EdgeInsets.only(right: 16),
            onTap: onLeft,
            iconColor: appColors.remoteGlyphOnRemote,
          ),
          _ArrowButton(
            alignment: Alignment.centerRight,
            icon: Icons.keyboard_arrow_right,
            iconPadding: const EdgeInsets.only(left: 16),
            onTap: onRight,
            iconColor: appColors.remoteGlyphOnRemote,
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appColors.remoteRaisedSurface,
              border: Border.all(color: appColors.remoteOutline, width: 1.4),
            ),
            child: TextButton(
              onPressed: onOk,
              style: TextButton.styleFrom(shape: const CircleBorder()),
              child: Text(
                'OK',
                style: TextStyle(
                  color: appColors.remoteGlyphOnRemote,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.alignment,
    required this.icon,
    required this.onTap,
    required this.iconColor,
    this.iconPadding = EdgeInsets.zero,
  });

  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final EdgeInsets iconPadding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 82,
        height: 82,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: iconPadding,
              child: Icon(icon, size: 46, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
