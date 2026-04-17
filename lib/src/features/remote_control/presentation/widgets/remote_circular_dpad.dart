import 'package:flutter/material.dart';

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
              color: const Color(0xFF111317),
              border: Border.all(color: const Color(0xFF2D3138), width: 1.4),
            ),
          ),
          _ArrowButton(
            alignment: Alignment.topCenter,
            icon: Icons.keyboard_arrow_up,
            iconPadding: const EdgeInsets.only(bottom: 16),
            onTap: onUp,
          ),
          _ArrowButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.keyboard_arrow_down,
            iconPadding: const EdgeInsets.only(top: 16),
            onTap: onDown,
          ),
          _ArrowButton(
            alignment: Alignment.centerLeft,
            icon: Icons.keyboard_arrow_left,
            iconPadding: const EdgeInsets.only(right: 16),
            onTap: onLeft,
          ),
          _ArrowButton(
            alignment: Alignment.centerRight,
            icon: Icons.keyboard_arrow_right,
            iconPadding: const EdgeInsets.only(left: 16),
            onTap: onRight,
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1B1D22),
              border: Border.all(color: const Color(0xFF2D3138), width: 1.4),
            ),
            child: TextButton(
              onPressed: onOk,
              style: TextButton.styleFrom(shape: const CircleBorder()),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
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
    this.iconPadding = EdgeInsets.zero,
  });

  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;
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
              child: Icon(icon, size: 46, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
