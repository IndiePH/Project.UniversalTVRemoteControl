import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_defaults.dart';
import 'package:one_remote/remote_control/presentation/widgets/remote_layout_item_definitions.dart';

void main() {
  group('RemoteLayoutDefaults.layoutFor', () {
    test('falls through to the global baseline when no override exists', () {
      const defaults = RemoteLayoutDefaults();

      for (final brand in TvBrand.values) {
        expect(
          defaults.layoutFor(brand, TvDevice.defaultProtocolVariant),
          same(kRemoteLayoutItemDefinitions),
          reason: '$brand has no RemoteLayoutDefaults entry today',
        );
      }
    });

    test('falls through to the global baseline for an unresolved variant', () {
      const defaults = RemoteLayoutDefaults();

      expect(
        defaults.layoutFor(TvBrand.androidTv, 'some-unresolved-variant'),
        same(kRemoteLayoutItemDefinitions),
      );
    });
  });

  group('resolveItemDefinitionsById', () {
    test('matches the global id map when no override exists', () {
      final resolved = resolveItemDefinitionsById(
        brand: TvBrand.androidTv,
        protocolVariant: TvDevice.defaultProtocolVariant,
      );

      expect(resolved, equals(kRemoteLayoutItemDefinitionById));
    });
  });

  group('buildFilteredRemoteLayoutItems definitions parameter', () {
    const onlyDefinition = RemoteLayoutItemDefinition(
      id: 'only-item',
      col: 0,
      row: 0,
      commands: {RemoteCommand.power},
    );

    test(
      'iterates the passed-in definitions instead of the global catalog',
      () {
        final items = buildFilteredRemoteLayoutItems(
          supportedCommands: {RemoteCommand.power},
          supportsTextInput: false,
          definitions: const [onlyDefinition],
        );

        expect(items, hasLength(1));
        expect(items.single.id, 'only-item');
      },
    );

    test(
      'still applies the command-support filter against custom definitions',
      () {
        final items = buildFilteredRemoteLayoutItems(
          supportedCommands: const {},
          supportsTextInput: false,
          definitions: const [onlyDefinition],
        );

        expect(items, isEmpty);
      },
    );

    test('defaults to the global catalog when no definitions are passed', () {
      final items = buildFilteredRemoteLayoutItems(
        supportedCommands: RemoteCommand.values.toSet(),
        supportsTextInput: true,
      );

      expect(items.length, kRemoteLayoutItemDefinitions.length);
    });
  });
}
