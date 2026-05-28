import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Calls the backend to validate store purchase proofs.
///
/// This is intentionally narrow and Android-only for now:
/// it verifies Google Play `purchaseToken` for the Pro product.
final class ProReceiptValidationService {
  ProReceiptValidationService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<void> _ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) {
      return;
    }
    await _auth.signInAnonymously();
  }

  Future<bool> verifyAndroidNonConsumable({
    required String productId,
    required String purchaseToken,
  }) async {
    await _ensureSignedIn();
    final callable = _functions.httpsCallable('verifyProAndroidPurchase');
    final result = await callable.call(<String, Object?>{
      'productId': productId,
      'purchaseToken': purchaseToken,
    });
    final data = result.data;
    if (data is Map) {
      final entitled = data['entitled'];
      if (entitled is bool) {
        return entitled;
      }
    }
    return false;
  }
}

