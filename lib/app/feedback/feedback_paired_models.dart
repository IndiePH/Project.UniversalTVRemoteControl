import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Builds a privacy-safe paired-TV summary for voluntary feedback.
///
/// Includes brand and commercial model only. Never includes device ids
/// (those embed LAN IPs), user-chosen names, serials, MACs, or pairing tokens.
abstract final class FeedbackPairedModels {
  static const int maxSummaryLength = 500;
  static const String modelUnknown = '(model unknown)';

  static const Set<String> _protocolMarkers = {
    'tcl_google_tv',
    'tcl_roku',
    'tcl_legacy_wifi',
    'roku',
  };

  static final RegExp _ipv4 = RegExp(r'\d{1,3}(?:\.\d{1,3}){3}');
  static final RegExp _mac = RegExp(
    r'(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}',
    caseSensitive: false,
  );

  static String summarize(Iterable<TvDevice> devices) {
    final parts = <String>[];
    for (final device in devices) {
      final brand = device.brand.displayName;
      final model = commercialModelOf(device);
      parts.add(model == null ? '$brand $modelUnknown' : '$brand $model');
    }
    if (parts.isEmpty) {
      return '';
    }
    final joined = parts.join('; ');
    if (joined.length <= maxSummaryLength) {
      return joined;
    }
    return '${joined.substring(0, maxSummaryLength - 1).trimRight()}…';
  }

  /// Returns a commercial model SKU, or null when only a protocol marker /
  /// identifier is available.
  static String? commercialModelOf(TvDevice device) {
    return sanitizeModel(device.modelIdentifier);
  }

  static String? sanitizeModel(String? raw) {
    var value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    if (_ipv4.hasMatch(value) || _mac.hasMatch(value)) {
      return null;
    }
    if (value.toLowerCase().startsWith('fake-')) {
      return null;
    }

    if (value.toLowerCase().startsWith('roku:')) {
      value = _rokuModelSegment(value) ?? '';
      if (value.isEmpty) {
        return null;
      }
    }

    final lower = value.toLowerCase();
    if (_protocolMarkers.contains(lower)) {
      return null;
    }
    if (value.length > 64) {
      return null;
    }
    return value;
  }

  static String? _rokuModelSegment(String value) {
    final parts = value.split(':');
    if (parts.length >= 3) {
      final model = parts[1].trim();
      return model.isEmpty ? null : model;
    }
    if (parts.length == 2) {
      final candidate = parts[1].trim();
      if (candidate.isEmpty) {
        return null;
      }
      final looksLikeSerial =
          candidate.length >= 10 &&
          !candidate.contains(' ') &&
          RegExp(r'^[A-Za-z0-9]+$').hasMatch(candidate);
      return looksLikeSerial ? null : candidate;
    }
    return null;
  }
}
