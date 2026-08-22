/// Shared layout-editor metrics for tests and stable editor chrome sizing.
library;

/// [TextTheme.titleLarge] font size used in layout-editor widget tests.
const double kRemoteLayoutEditorTitleFontSize = 18;

/// [TextTheme.bodyMedium] font size used in layout-editor widget tests.
const double kRemoteLayoutEditorBodyFontSize = 12;

/// Viewport width for [RemoteLayoutEditor] widget tests (phone-like).
const double kRemoteLayoutEditorTestViewportWidth = 400;

/// Viewport height for [RemoteLayoutEditor] widget tests (phone-like).
const double kRemoteLayoutEditorTestViewportHeight = 900;

/// Vertical gap between the layout-editor title row and instruction text.
const double kRemoteLayoutEditorInstructionTopSpacing = 6;

/// Fixed height of the always-visible drawer strip, between the header and the grid canvas.
///
/// Fixed, not content-sized — a strip that grew or shrank with its contents would shift the
/// grid's cell size every time an item entered or left the drawer.
const double kRemoteLayoutDrawerStripHeight = 88;

/// `cellSize` passed to [RemoteLayoutEditorItemPreview] for drawer-strip items.
///
/// Independent of the grid's cell size. Multi-cell items (dpad, volume, channel) render taller
/// than the strip if parked here — accepted as a rare cosmetic edge case.
const double kRemoteLayoutDrawerItemCellSize = 56;

/// Vertical gap between the drawer strip and its neighboring header/grid regions.
const double kRemoteLayoutDrawerStripSpacing = 8;

/// Tap target size (width and height) of each drawer scroll chevron.
const double kRemoteLayoutDrawerChevronSize = 36;

/// Gap between each scroll triangle and the drawer box next to it.
const double kRemoteLayoutDrawerChevronGap = 4;

/// Pixels moved per timer tick while a drawer scroll triangle is held down.
const double kRemoteLayoutDrawerAutoScrollPixelsPerTick = 6;

/// Timer tick interval for continuous scroll while a drawer scroll triangle is held down.
const Duration kRemoteLayoutDrawerAutoScrollTickInterval = Duration(
  milliseconds: 16,
);
