import 'package:shared_preferences/shared_preferences.dart';

/// Persists the LG webOS client-key across app restarts using SharedPreferences.
///
/// Keys are scoped per TV host so multiple LG TVs on the same network are
/// supported independently. Mirrors [RealSamsungPairingTokenStore] but backed
/// by SharedPreferences rather than in-memory storage.
class RealLgPairingKeyStore {
  static const String _keyPrefix = 'lg_client_key_';

  Future<void> storeKeyForHost(String host, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$host', key);
  }

  Future<String?> keyForHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix$host');
  }

  Future<void> clearKeyForHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$host');
  }
}
