/// Parses the Bluetooth MAC address a TV advertises via its
/// `_androidtvremote2._tcp` mDNS TXT record's `bt=` field.
///
/// This is a passive, connection-independent identity signal for Android
/// TV/Google TV discovery -- unlike the certificate-based stable id, it
/// doesn't require a live TLS handshake to read. Not every Android TV
/// firmware advertises it; absence is expected and must fall back cleanly
/// to the existing IP-derived id, not be treated as an error. See
/// `references/goals/goal-automatic-reconnection-resilience.md` SG3/T3.1-T3.2.
final class AndroidTvBluetoothMacTxtParser {
  const AndroidTvBluetoothMacTxtParser._();

  /// Extracts the `bt=<mac>` entry from [rawText] -- the newline-joined set
  /// of `key=value` pairs `TxtResourceRecord.text` decodes a DNS-SD TXT
  /// record's length-prefixed strings into (see `package:multicast_dns`'s
  /// packet reader). Returns the MAC lowercased for consistent id strings
  /// across scans, or `null` when no `bt` key is present or its value is
  /// empty.
  static String? parse(String rawText) {
    for (final line in rawText.split('\n')) {
      final separatorIndex = line.indexOf('=');
      if (separatorIndex == -1) continue;
      final key = line.substring(0, separatorIndex).trim();
      if (key != 'bt') continue;
      final value = line.substring(separatorIndex + 1).trim();
      if (value.isEmpty) continue;
      return value.toLowerCase();
    }
    return null;
  }
}
