/// Resolves an already-paired Android TV's stable identity at a LAN host.
///
/// Implementations must return null when the host cannot be proven to belong
/// to a certificate already known by this app.
abstract interface class AndroidTvStableIdentityResolver {
  Future<String?> discoverStableIdAtHost(String host);
}
