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
/// Fixed (not content-dependent) deliberately: the grid's `fitCellSize` computes available space
/// once per build from the `Column`'s remaining space, so a strip that resized with its contents
/// would shift the grid's cell size every time an item entered or left the drawer.
const double kRemoteLayoutDrawerStripHeight = 88;

/// `cellSize` passed to [RemoteLayoutEditorItemPreview] for drawer-strip items.
///
/// Independent of the grid's dynamically-fitted cell size — the drawer strip is a fixed height,
/// so its items use a fixed preview size too, per the class doc's "look and feel may diverge"
/// allowance. Multi-cell items (dpad, volume, channel) are rare drawer contents but will render
/// taller than the strip if parked there; accepted as a minor cosmetic edge case rather than
/// adding scaling logic for it.
const double kRemoteLayoutDrawerItemCellSize = 56;

/// Vertical gap between the drawer strip and its neighboring header/grid regions.
const double kRemoteLayoutDrawerStripSpacing = 8;
