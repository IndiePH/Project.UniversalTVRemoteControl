import 'package:one_remote/remote_control/application/text_compatibility_error.dart';

class TextInputCompatibilityException implements Exception {
  TextInputCompatibilityException(this.error);

  final TextCompatibilityError error;
}
