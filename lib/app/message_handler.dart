import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/remote_control/application/result.dart';

final class MessageHandler {
  const MessageHandler._();

  /// Returns [result.message] enriched with exception detail when the current
  /// [AppEnvironment] is not production. Safe to call with any [Result] subtype.
  static String sanitize(Result result) {
    if (result.exception == null) return result.message;
    final env = GetIt.instance<AppEnvironment>();
    return env != AppEnvironment.production
        ? '${result.message}: ${result.exception}'
        : result.message;
  }
}
