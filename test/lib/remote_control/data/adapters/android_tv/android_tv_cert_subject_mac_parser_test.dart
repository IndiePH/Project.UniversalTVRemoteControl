import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_cert_subject_mac_parser.dart';

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

  group('AndroidTvCertSubjectMacParser', () {
    test('extracts the MAC from an NVIDIA Shield-shaped CN', () {
      final der = certDerWithCn(
        'atvremote/darcy/darcy/SHIELD Android TV/AA:BB:CC:DD:EE:FF',
      );
      expect(
        AndroidTvCertSubjectMacParser.parseFromDer(der),
        'aa:bb:cc:dd:ee:ff',
      );
    });

    test('extracts the MAC from a Nexus Player-shaped CN (MAC-only, no name)', () {
      // Nexus Player splits the device name into dnQualifier, leaving only
      // "atvremote/<mac>" in CN -- basic_utils's CSR builder only accepts a
      // CN attribute, so this covers the CN-side shape the parser reads;
      // dnQualifier is irrelevant to MAC extraction per the ported algorithm.
      final der = certDerWithCn('atvremote/AA:BB:CC:DD:EE:FF');
      expect(
        AndroidTvCertSubjectMacParser.parseFromDer(der),
        'aa:bb:cc:dd:ee:ff',
      );
    });

    test('returns null when the CN has no MAC-shaped trailing segment', () {
      final der = certDerWithCn('atvremote/darcy/SHIELD Android TV');
      expect(AndroidTvCertSubjectMacParser.parseFromDer(der), isNull);
    });

    test('returns null for a single-token CN with no MAC at all', () {
      final der = certDerWithCn('OneRemote');
      expect(AndroidTvCertSubjectMacParser.parseFromDer(der), isNull);
    });

    test('returns null for malformed DER instead of throwing', () {
      expect(
        AndroidTvCertSubjectMacParser.parseFromDer(
          Uint8List.fromList([1, 2, 3]),
        ),
        isNull,
      );
    });

    test('returns null for empty DER instead of throwing', () {
      expect(
        AndroidTvCertSubjectMacParser.parseFromDer(Uint8List(0)),
        isNull,
      );
    });
  });
}
