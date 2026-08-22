/// Named string constants for layout item identity.
///
/// Kept as plain `String` (not an enum) deliberately: [LayoutEditItem.id] flows through
/// `Map<String, ...>` persistence keys and `Draggable<String>`/`DragTarget<String>` drag-and-drop
/// generics, and the pure grid-geometry layer ([RemoteLayoutDropResolver] and its drag session)
/// is tested with synthetic, non-catalog ids for stress-testing that have no equivalent here.
/// These constants exist only to replace scattered raw string literals with compile-time-checked,
/// autocomplete-friendly references — the underlying type and every existing `String`-keyed
/// structure are unchanged.
abstract final class LayoutItemId {
  static const String power = 'power';
  static const String menu = 'menu';
  static const String volume = 'volume';
  static const String playPause = 'playPause';
  static const String www = 'www';
  static const String dpad = 'dpad';
  static const String channel = 'channel';
  static const String home = 'home';
  static const String back = 'back';
  static const String mute = 'mute';
  static const String netflix = 'netflix';
  static const String disney = 'disney';
  static const String prime = 'prime';
  static const String searchInput = 'searchInput';
  static const String youtube = 'youtube';
  static const String input = 'input';
}
