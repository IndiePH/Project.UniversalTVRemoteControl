import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:one_remote/app/monetization/pro_receipt_validation_result.dart';

/// Calls the backend to validate store purchase proofs.
///
/// This is intentionally narrow and Android-only for now:
/// it verifies Google Play `purchaseToken` for the Pro product.
final class ProReceiptValidationService {
  static const String functionsRegion = 'asia-southeast1';

  ProReceiptValidationService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  late final HttpsCallable _verifyCallable = _functions.httpsCallable(
    'verifyProAndroidPurchase',
  );

  Future<void> _ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) {
      return;
    }
    await _auth.signInAnonymously();
  }

  Future<ProReceiptValidationResult> verifyAndroidPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    await _ensureSignedIn();
    final uid = _auth.currentUser?.uid;
    developer.log(
      'Calling verifyProAndroidPurchase '
      '(region=$functionsRegion, productId=$productId, uid=$uid, '
      'tokenLength=${purchaseToken.length})',
      name: 'ProReceiptValidation',
    );
    final callable = _verifyCallable;
    try {
      final result = await callable.call(<String, Object?>{
        'productId': productId,
        'purchaseToken': purchaseToken,
      });
      final data = result.data;
      if (data is Map) {
        final entitled = data['entitled'];
        if (entitled is bool) {
          final expiresAtEpochMs = _readEpochMs(data['expiresAtEpochMs']);
          final resolvedProductId = data['productId'];
          developer.log(
            'verifyProAndroidPurchase succeeded '
            '(entitled=$entitled, productId=$productId, '
            'expiresAtEpochMs=$expiresAtEpochMs)',
            name: 'ProReceiptValidation',
          );
          return ProReceiptValidationResult(
            entitled: entitled,
            expiresAtEpochMs: expiresAtEpochMs,
            resolvedProductId: resolvedProductId is String
                ? resolvedProductId
                : productId,
          );
        }
      }
      developer.log(
        'verifyProAndroidPurchase returned unexpected payload',
        name: 'ProReceiptValidation',
        level: 900,
      );
      return const ProReceiptValidationResult.notEntitled();
    } on FirebaseFunctionsException catch (e, stackTrace) {
      developer.log(
        'verifyProAndroidPurchase failed: ${e.code} ${e.message}',
        name: 'ProReceiptValidation',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint('verifyProAndroidPurchase failed: ${e.code} ${e.message}');
      }
      rethrow;
    }
  }

  int? _readEpochMs(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
