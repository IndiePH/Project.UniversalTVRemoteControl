/// Shared animation timings for the pairing-hint affordance.
///
/// Multiple widgets cross-fade together when the user taps a disabled control
/// while no TV is paired: the remote grid's [AnimatedSwitcher] swaps in a
/// dimmed copy while the status panel blurs its labels and pulses the pair
/// button. Keeping a single duration here prevents the two transitions from
/// drifting out of sync.
library;

/// Cross-fade duration shared by the remote grid's pairing-hint switcher and
/// the status panel's blur-when-pair-focus overlay.
const Duration kRemotePairingHintFadeDuration = Duration(milliseconds: 250);
