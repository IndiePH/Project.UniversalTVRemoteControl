import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_certificate_store.dart';

void main() {
  late RSAPrivateKey privateKey;
  late RSAPublicKey publicKey;

  setUpAll(() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    privateKey = pair.privateKey as RSAPrivateKey;
    publicKey = pair.publicKey as RSAPublicKey;
  });

  Uint8List certDerWithCn(String cn) {
    final csr = X509Utils.generateRsaCsrPem({'CN': cn}, privateKey, publicKey);
    final certPem = X509Utils.generateSelfSignedCertificate(privateKey, csr, 1);
    final body = certPem
        .replaceAll(X509Utils.BEGIN_CERT, '')
        .replaceAll(X509Utils.END_CERT, '')
        .replaceAll(RegExp(r'\s'), '');
    return base64.decode(body);
  }

  group('AndroidTvCertificateStore.stableIdFromDer', () {
    test('prefers the subject MAC when the CN embeds one', () {
      final der = certDerWithCn('atvremote/AA:BB:CC:DD:EE:FF');
      expect(
        AndroidTvCertificateStore.stableIdFromDer(der),
        'androidtv-aa:bb:cc:dd:ee:ff',
      );
    });

    test(
      'falls back to the whole-DER hash when no MAC is embedded in the subject',
      () {
        final der = certDerWithCn('OneRemote');
        expect(
          AndroidTvCertificateStore.stableIdFromDer(der),
          AndroidTvCertificateStore.stableIdFromServerCertificate(der),
        );
      },
    );
  });
}
