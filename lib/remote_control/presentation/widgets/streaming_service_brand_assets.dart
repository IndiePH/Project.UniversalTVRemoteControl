import 'package:flutter/material.dart';

/// Asset paths and display colors for streaming-app shortcut buttons.
abstract final class StreamingServiceBrandAssets {
  static const netflix = 'assets/icons/streaming/netflix.svg';
  static const primeVideo = 'assets/icons/streaming/prime_video.svg';
  static const disneyPlus = 'assets/icons/streaming/disney_plus.svg';

  /// Monochrome SVG tint for Netflix (Simple Icons, CC0).
  static const Color netflixBrand = Color(0xFFE50914);

  /// Monochrome SVG tint for Prime Video wordmark (`prime_video.svg`).
  static const Color primeVideoBrand = Color(0xFF00A8E1);
}
