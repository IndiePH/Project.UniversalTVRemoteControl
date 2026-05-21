import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_remote/remote_control/presentation/widgets/layout_edit_item.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_circular_dpad.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_icon_circle_button.dart';
import 'package:one_remote/remote_control/presentation/metrics/remote_layout_button_metrics.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_vertical_rocker.dart';
import 'package:one_remote/theme/app_theme.dart';

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
    // Inset preview content so the editor's background cell box stays visible
    // as a frame around each control instead of being hidden by the circle.
    final inset = cellSize * kRemoteLayoutCellInsetRatio;
    final innerWidth = math.max(1.0, width - inset * 2);
    final innerHeight = math.max(1.0, height - inset * 2);
    final definition = itemDefinitionsById[item.id];
    final previewStyle = definition?.previewStyle ?? RemoteLayoutPreviewStyle.standard;
    final icon = definition?.icon ?? item.icon;
    final imageAsset = definition?.imageAsset ?? item.imageAsset;
    final imageIconSize = definition?.imageIconSize;
    final brandColor = definition?.brandColor;
    final label = definition?.label ?? item.label;
    final isPower = definition?.isPower ?? item.isPower;
    final isSingleCell = item.width == 1 && item.height == 1;

    if (previewStyle == RemoteLayoutPreviewStyle.circularDpad) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.all(inset),
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
        ),
      );
    }
    if (previewStyle == RemoteLayoutPreviewStyle.verticalRocker) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.all(inset),
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
        ),
      );
    }

    final appColors = AppTheme.colorsOf(context);
    final background = isPower ? appColors.remotePowerFill : appColors.remoteSurface;

    // Single-cell items that boil down to a circular icon/label button render
    // through the same widget the home grid uses
    // ([RemoteIconCircleButton] inside [FittedBox]) so labels like "WWW" and
    // icons like the keyboard glyph scale identically in edit and live modes.
    // Larger standard items fall back to the rounded-rectangle shell below.
    final usesIconCircleButton = isSingleCell &&
        (previewStyle == RemoteLayoutPreviewStyle.standard ||
            previewStyle == RemoteLayoutPreviewStyle.centeredCircleIcon);
    if (usesIconCircleButton) {
      return RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: FittedBox(
              fit: BoxFit.contain,
              child: AbsorbPointer(
                child: RemoteIconCircleButton(
                  icon: icon,
                  imageAsset: imageAsset,
                  imageIconSize: imageIconSize,
                  brandColor: brandColor,
                  label: label,
                  isPower: isPower,
                  onPressed: null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Container(
            decoration: BoxDecoration(
              shape: isSingleCell ? BoxShape.circle : BoxShape.rectangle,
              borderRadius:
                  isSingleCell ? null : BorderRadius.circular(cellSize * 0.6),
              color: background,
              border: Border.all(
                color: appColors.remoteOutline,
                width: kRemoteIconCircleButtonBorderWidth,
              ),
            ),
            child: switch (previewStyle) {
              RemoteLayoutPreviewStyle.playPause => Builder(
                  builder: (_) {
                    final glyphSize = math.min(innerWidth, innerHeight) *
                        kRemotePlayPauseGlyphSizeRatio;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kRemotePlayPauseInnerHorizontalPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow,
                            color: appColors.remoteGlyphOnRemote,
                            size: glyphSize + kRemotePlayPausePlayGlyphBoost,
                          ),
                          SizedBox(
                            width: math.max(
                              1,
                              glyphSize * kRemotePlayPauseGlyphGapRatio,
                            ),
                          ),
                          Icon(
                            Icons.pause,
                            color: appColors.remoteGlyphOnRemote,
                            size: glyphSize + kRemotePlayPausePauseGlyphBoost,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              RemoteLayoutPreviewStyle.centeredCircleIcon => Center(
                  child: RemoteIconCircleButton(
                    icon: icon,
                    imageAsset: imageAsset,
                    imageIconSize: imageIconSize,
                    brandColor: brandColor,
                    label: label,
                    onPressed: null,
                  ),
                ),
              // Multi-cell standard fallback (no single-cell items reach here:
              // they are handled by the [RemoteIconCircleButton] path above).
              RemoteLayoutPreviewStyle.standard => icon != null
                  ? Icon(
                      icon,
                      size: math.min(innerWidth, innerHeight) * 0.45,
                      color: appColors.remoteGlyphOnRemote,
                    )
                    : Center(
                      child: Text(
                        label ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: appColors.remoteGlyphOnRemote,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
              RemoteLayoutPreviewStyle.circularDpad => const SizedBox.shrink(),
              RemoteLayoutPreviewStyle.verticalRocker => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}
