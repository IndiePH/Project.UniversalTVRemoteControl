/// Shared layout metrics for the remote home / layout-editor header sections.
///
/// Keeping a single source of truth here prevents drift between the live remote
/// view ([RemoteHomeStatusPanel]) and the editor view ([RemoteLayoutEditor]) so
/// the grid below either header starts at the same vertical position.
library;

/// Fixed pixel height reserved for the header section above the remote grid.
///
/// Sized to fit the taller of the two headers (the editor's title row + reset
/// button + multi-line instruction text) so both modes align visually.
const double kRemoteLayoutHeaderHeight = 106;
