/// Shared grid dimensions for the remote home layout and layout editor.
///
/// Single source of truth so the live remote ([RemoteHomePage]),
/// editor ([RemoteLayoutEditor]), and layout constraint tests stay aligned.
library;

/// Column count for the default remote control grid.
const int kRemoteLayoutGridColumns = 5;

/// Row count for the default remote control grid.
const int kRemoteLayoutGridRows = 9;

/// Pixel gap between grid cells on the home remote and in the layout editor.
const double kRemoteLayoutGridGap = 6;
