import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_di_config.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/app/stream_unhandled_error_source.dart';
import 'package:one_remote/app/unhandled_error_source.dart';

void main() {
  group('DevAppDiConfig', () {
    late GetIt sl;

    setUp(() => sl = GetIt.asNewInstance());
    tearDown(() => sl.reset());

    test('registers StreamUnhandledErrorSource', () {
      const DevAppDiConfig().configure(sl, AppEnvironment.debug);
      expect(sl.isRegistered<StreamUnhandledErrorSource>(), isTrue);
    });

    test('registers UnhandledErrorSource', () {
      const DevAppDiConfig().configure(sl, AppEnvironment.debug);
      expect(sl.isRegistered<UnhandledErrorSource>(), isTrue);
    });

    test('both registrations resolve to the same instance', () {
      const DevAppDiConfig().configure(sl, AppEnvironment.debug);
      expect(
        sl<StreamUnhandledErrorSource>(),
        same(sl<UnhandledErrorSource>()),
      );
    });

    test('registers under development environment', () {
      const DevAppDiConfig().configure(sl, AppEnvironment.development);
      expect(sl.isRegistered<UnhandledErrorSource>(), isTrue);
    });
  });
}
