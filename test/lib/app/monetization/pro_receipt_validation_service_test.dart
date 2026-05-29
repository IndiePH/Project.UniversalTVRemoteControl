import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/monetization/pro_receipt_validation_service.dart';

void main() {
  test('uses the deployed callable functions region', () {
    expect(ProReceiptValidationService.functionsRegion, 'asia-southeast1');
  });
}
