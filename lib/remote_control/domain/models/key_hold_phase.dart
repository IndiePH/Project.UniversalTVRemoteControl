/// Distinguishes a key press's down/up edge for brands with a native hold primitive
/// (Android TV's `START_LONG`/`END_LONG`, Samsung's `Press`/`Release`, Roku's
/// `/keydown//keyup`). Adapters without a native primitive throw `UnsupportedError`
/// from `TvBrandAdapter.sendKeyHold` rather than emulating one — see
/// `references/goals/goal-long-press-key.md`.
enum KeyHoldPhase { down, up }
