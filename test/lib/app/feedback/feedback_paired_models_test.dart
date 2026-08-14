import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/feedback/feedback_paired_models.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

TvDevice _device({
  required String id,
  required TvBrand brand,
  String displayName = 'Living room',
  String? modelIdentifier,
}) {
  return TvDevice(
    id: id,
    displayName: displayName,
    brand: brand,
    capabilities: const {DeviceCapability.powerControl},
    modelIdentifier: modelIdentifier,
  );
}

void main() {
  test('summarizes brand and commercial model only', () {
    final summary = FeedbackPairedModels.summarize([
      _device(
        id: 'samsung-192.168.1.10',
        brand: TvBrand.samsung,
        displayName: "Mom's bedroom",
        modelIdentifier: 'UN55TU8000',
      ),
      _device(
        id: 'lg-10.0.0.5',
        brand: TvBrand.lg,
        modelIdentifier: 'OLED55C3PUA',
      ),
    ]);

    expect(summary, 'Samsung UN55TU8000; LG OLED55C3PUA');
    expect(summary, isNot(contains('192.168')));
    expect(summary, isNot(contains("Mom's")));
  });

  test('uses model unknown when SKU was never captured', () {
    final summary = FeedbackPairedModels.summarize([
      _device(id: 'hisense-192.168.1.20', brand: TvBrand.hisense),
      _device(
        id: 'androidtv-192.168.1.21',
        brand: TvBrand.androidTv,
        modelIdentifier: 'tcl_google_tv',
      ),
    ]);

    expect(summary, 'Hisense (model unknown); Android TV (model unknown)');
  });

  test('strips Roku serial and keeps commercial model', () {
    expect(
      FeedbackPairedModels.sanitizeModel('roku:55S455:YR001234ABCD'),
      '55S455',
    );
    expect(FeedbackPairedModels.sanitizeModel('roku:YR001234ABCD'), isNull);
    expect(FeedbackPairedModels.sanitizeModel('tcl_legacy_wifi'), isNull);
  });

  test('rejects IPs and MACs in model field', () {
    expect(FeedbackPairedModels.sanitizeModel('192.168.1.10'), isNull);
    expect(FeedbackPairedModels.sanitizeModel('aa:bb:cc:dd:ee:ff'), isNull);
  });

  test('empty device list is empty string', () {
    expect(FeedbackPairedModels.summarize(const []), '');
  });
}
