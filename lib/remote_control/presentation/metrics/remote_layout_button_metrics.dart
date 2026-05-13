/// Shared sizing for the circular buttons used in the remote home and layout
/// editor.
///
/// Single source of truth so a button looks identical whether it is the live
/// version on [RemoteHomePage] or its non-interactive twin inside
/// [RemoteLayoutEditor]. Mirrors the pattern of
/// [kRemoteLayoutHeaderHeight] in `remote_layout_header_metrics.dart`.
library;

/// Outer diameter of header row icon buttons
/// (pair button on the home view, layout-reset button in the editor).
const double kRemoteHeaderButtonSize = 44;

/// Glyph size inside header row icon buttons.
const double kRemoteHeaderButtonIconSize = 24;

/// Border width of header row icon buttons in their default (non-highlighted)
/// state. Highlight states may temporarily widen the stroke; default stays
/// here so both modes match at rest.
const double kRemoteHeaderButtonBorderWidth = 1.2;

/// Outer diameter of in-grid remote control buttons
/// (the circular buttons rendered inside each layout cell).
///
/// The actual rendered size on screen is this value scaled by the surrounding
/// [FittedBox] so it fits within `cellSize * (1 - 2 * kRemoteLayoutCellInsetRatio)`.
const double kRemoteIconCircleButtonSize = 72;

/// Icon glyph size inside in-grid remote control buttons. Scales with the
/// button via the shared [FittedBox] wrapper.
const double kRemoteIconCircleButtonIconSize = 34;

/// Border width of in-grid remote control buttons.
const double kRemoteIconCircleButtonBorderWidth = 1.2;

/// Fraction of `cellSize` reserved as padding around each grid item so the
/// underlying cell frame remains visible. Applied identically on the live
/// remote and the editor preview to keep visuals aligned.
const double kRemoteLayoutCellInsetRatio = 0.05;

// ---------------------------------------------------------------------------
// Play / pause pill
//
// The play/pause control is a pill-shaped (non-circular) button rendered in
// both the live remote grid and the editor preview. Its glyph sizing rules
// are duplicated across those two call sites and must stay in lockstep, so
// every visual ratio is anchored here.
// ---------------------------------------------------------------------------

/// Base glyph size in the play/pause pill, as a fraction of the shorter inner
/// dimension of the pill.
const double kRemotePlayPauseGlyphSizeRatio = 0.24;

/// Extra pixels added to the play-arrow icon on top of the base glyph size.
/// Keeps the visually thinner arrow glyph optically balanced with the pause
/// bars.
const double kRemotePlayPausePlayGlyphBoost = 2;

/// Extra pixels added to the pause icon on top of the base glyph size.
const double kRemotePlayPausePauseGlyphBoost = 1;

/// Horizontal gap between the play and pause glyphs, expressed as a fraction
/// of the base glyph size.
const double kRemotePlayPauseGlyphGapRatio = 0.08;

/// Inner horizontal padding inside the play/pause pill row.
const double kRemotePlayPauseInnerHorizontalPadding = 4;
