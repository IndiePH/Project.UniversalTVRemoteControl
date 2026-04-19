import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/src/features/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/src/theme/app_theme.dart';

void _noop() {}

/// Non-interactive preview of one layout cell cluster in the layout editor.
class RemoteLayoutEditorItemPreview extends StatelessWidget {
  const RemoteLayoutEditorItemPreview({
    super.key,
    required this.item,
    required this.cellSize,
    required this.gridGap,
    required this.itemDefinitionsById,
  });

  final LayoutEditItem item;
  final double cellSize;
  final double gridGap;
  final Map<String, RemoteLayoutItemDefinition> itemDefinitionsById;

  @override
  Widget build(BuildContext context) {
    final width = (item.width * cellSize) + ((item.width - 1) * gridGap);
    final height = (item.height * cellSize) + ((item.height - 1) * gridGap);
    final definition = itemDefinitionsById[item.id];
    final previewStyle = definition?.previewStyle ?? RemoteLayoutPreviewStyle.standard;
    final icon = definition?.icon ?? item.icon;
    final label = definition?.label ?? item.label;
    final isPower = definition?.isPower ?? item.isPower;

    if (previewStyle == RemoteLayoutPreviewStyle.circularDpad) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: AbsorbPointer(
              child: RemoteCircularDpad(
                onUp: _noop,
                onDown: _noop,
                onLeft: _noop,
                onRight: _noop,
                onOk: _noop,
              ),
            ),
          ),
        ),
      );
    }
    if (previewStyle == RemoteLayoutPreviewStyle.verticalRocker) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.fill,
            child: AbsorbPointer(
              child: RemoteVerticalRocker(
                topText: '+',
                centerText: label ?? '',
                bottomText: '-',
                onTopTap: _noop,
                onBottomTap: _noop,
              ),
            ),
          ),
        ),
      );
    }

    final appColors = AppTheme.colorsOf(context);
    final background = isPower ? Colors.red.shade600 : appColors.remoteSurface;

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: item.width == 1 && item.height == 1
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: item.width == 1 && item.height == 1
              ? null
              : BorderRadius.circular(cellSize * 0.6),
          color: background,
          border: Border.all(color: appColors.remoteOutline, width: 1.2),
        ),
        child: switch (previewStyle) {
          RemoteLayoutPreviewStyle.playPause => Builder(
              builder: (_) {
                final glyphSize = math.min(width, height) * 0.24;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: glyphSize + 2,
                      ),
                      SizedBox(width: math.max(1, glyphSize * 0.08)),
                      Icon(Icons.pause, color: Colors.white, size: glyphSize + 1),
                    ],
                  ),
                );
              },
            ),
          RemoteLayoutPreviewStyle.centeredCircleIcon => Center(
              child: RemoteIconCircleButton(
                icon: icon,
                label: label,
                onPressed: null,
              ),
            ),
          RemoteLayoutPreviewStyle.standard => icon != null
              ? Icon(
                  icon,
                  size: math.min(width, height) * 0.45,
                  color: Colors.white,
                )
              : Center(
                  child: Text(
                    label ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
          RemoteLayoutPreviewStyle.circularDpad => const SizedBox.shrink(),
          RemoteLayoutPreviewStyle.verticalRocker => const SizedBox.shrink(),
        },
      ),
    );
  }
}
