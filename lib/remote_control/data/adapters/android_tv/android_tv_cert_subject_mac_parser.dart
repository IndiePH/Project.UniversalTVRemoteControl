import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

/// Extracts the Bluetooth MAC address embedded in an Android TV Remote v2
/// pairing certificate's subject.
///
/// Ports `tronikos/androidtvremote2`'s `_parse_name_and_mac` (verified against
/// its actual source): the MAC is always the last `/`-separated segment of
/// the certificate subject's Common Name (CN) field -- `dnQualifier` carries
/// the device name only, never the MAC, in both confirmed real-world shapes:
///
/// - NVIDIA Shield: `CN=atvremote/darcy/darcy/SHIELD Android TV/XX:XX:XX:XX:XX:XX`
/// - Nexus Player: `dnQualifier=fugu/fugu/Nexus Player/CN=atvremote/XX:XX:XX:XX:XX:XX`
///
/// Unlike the reference implementation, which trusts the last CN segment
/// blindly, this validates it actually looks like a MAC before accepting it.
/// The reference only ever uses the value for display; this app uses it as a
/// stable identifier matched by exact string equality on every scan, so a
/// third, unrecognized OEM subject shape must fall back cleanly (return
/// null) rather than mint a garbage id from an unrelated CN string.
///
/// See `references/goals/goal-automatic-reconnection-resilience.md` D-8/SG5/T5.1.
final class AndroidTvCertSubjectMacParser {
  const AndroidTvCertSubjectMacParser._();

  static final RegExp _macShape = RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}$');

  /// The X.520 Common Name OID, per `X509Utils.DN['cn']` -- looked up by OID
  /// rather than a human-readable key because `basic_utils` keys a parsed
  /// certificate's subject map by raw OID string, not by name.
  static final String _commonNameOid = X509Utils.DN['cn']!;

  /// Returns the lowercased MAC embedded in [der]'s subject Common Name, or
  /// null (not an error) when absent, empty, or not MAC-shaped -- caller
  /// falls back to the whole-DER hash, never crashes or drops straight to an
  /// IP-derived id.
  static String? parseFromDer(Uint8List der) {
    try {
      final subject = X509Utils.x509CertificateFromPem(
        _toPem(der),
      ).tbsCertificate?.subject;
      final commonName = subject?[_commonNameOid];
      if (commonName == null || commonName.isEmpty) return null;

      final candidate = commonName.split('/').last.toLowerCase();
      return _macShape.hasMatch(candidate) ? candidate : null;
    } catch (_) {
      // Malformed/unexpected DER can throw several distinct exception types
      // from the underlying ASN.1 parser with no single narrower type to
      // catch -- best-effort, matching this codebase's existing pattern for
      // discovery-time parsing (see references/tech-debt-list.md).
      return null;
    }
  }

  static String _toPem(Uint8List der) =>
      '${X509Utils.BEGIN_CERT}\n'
      '${StringUtils.chunk(base64.encode(der), 64).join('\n')}\n'
      '${X509Utils.END_CERT}';
}
