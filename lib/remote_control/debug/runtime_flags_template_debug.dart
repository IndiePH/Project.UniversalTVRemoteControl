import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:one_remote/app/configurations/app_environment.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Debug-only helpers for generating and copying runtime flag templates.
final class RuntimeFlagsTemplateDebug {
  const RuntimeFlagsTemplateDebug._();

  static Future<void> copyRuntimeFlagsTemplate({
    required TvDevice? activeDevice,
  }) async {
    final template = buildRuntimeFlagsTemplate(activeDevice: activeDevice);
    await Clipboard.setData(ClipboardData(text: template));
  }

  static String buildRuntimeFlagsTemplate({
    required TvDevice? activeDevice,
  }) {
    final useFakeTransports =
        GetIt.instance<AppEnvironment>() == AppEnvironment.debug;
    final brand = activeDevice?.brand;
    final lines = switch (brand) {
      // Keep in sync with references/samsung_validation_matrix.md -> Environment -> Runtime flags.
      TvBrand.samsung => <String>[
        '--dart-define=USE_FAKE_TRANSPORTS=$useFakeTransports',
        '--dart-define=SAMSUNG_ENABLE_TEXT_INPUT=false',
        '--dart-define=SAMSUNG_SEND_INPUT_END_PER_TEXT=false',
        '--dart-define=TV_HOST_OVERRIDE=<tv-ip>',
      ],
      TvBrand.hisense => <String>[
        '--dart-define=USE_FAKE_TRANSPORTS=$useFakeTransports',
        '--dart-define=TV_HOST_OVERRIDE=<tv-ip>',
        '--dart-define=HISENSE_MQTT_CLIENT_ID=OneRemote',
        '--dart-define=HISENSE_MQTT_PLAINTEXT=false',
      ],
      TvBrand.lg => <String>[
        '--dart-define=USE_FAKE_TRANSPORTS=$useFakeTransports',
        '--dart-define=TV_HOST_OVERRIDE=<tv-ip>',
      ],
      null => <String>[
        '--dart-define=USE_FAKE_TRANSPORTS=$useFakeTransports',
        '--dart-define=TV_HOST_OVERRIDE=<tv-ip>',
        '--dart-define=SAMSUNG_ENABLE_TEXT_INPUT=false',
        '--dart-define=SAMSUNG_SEND_INPUT_END_PER_TEXT=false',
        '--dart-define=HISENSE_MQTT_CLIENT_ID=OneRemote',
        '--dart-define=HISENSE_MQTT_PLAINTEXT=false',
      ],
    };
    return lines.join('\n');
  }
}
