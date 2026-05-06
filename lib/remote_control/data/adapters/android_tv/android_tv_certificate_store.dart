import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/asn1.dart';

/// Manages the mutual-TLS client certificate and server certificate storage
/// for the Android TV v2 remote protocol.
///
/// On first use, generates an RSA-2048 self-signed cert + key pair and persists
/// them to the app documents directory. Subsequent launches load from disk.
///
/// Server certificates received during pairing are stored per-host; their RSA
/// components (modulus + exponent) are extracted at store-time for use in the
/// SHA-256 pairing secret formula without re-parsing the DER on each call.
class AndroidTvCertificateStore {
  static const _clientCertFile = 'android_tv_client.cert.pem';
  static const _clientKeyFile = 'android_tv_client.key.pem';
  static const _clientRsaFile = 'android_tv_client.rsa.json';

  Future<void>? _initFuture;
  SecurityContext? _clientContext;
  BigInt? _clientModulus;
  BigInt? _clientExponent;

  Future<void> _ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    final certFile = File('${dir.path}/$_clientCertFile');
    final keyFile = File('${dir.path}/$_clientKeyFile');
    final rsaFile = File('${dir.path}/$_clientRsaFile');

    if (certFile.existsSync() && keyFile.existsSync() && rsaFile.existsSync()) {
      final certPem = await certFile.readAsString();
      final keyPem = await keyFile.readAsString();
      final rsa = jsonDecode(await rsaFile.readAsString()) as Map<String, dynamic>;
      _clientModulus = BigInt.parse(rsa['m'] as String, radix: 16);
      _clientExponent = BigInt.parse(rsa['e'] as String, radix: 16);
      _clientContext = _makeContext(certPem, keyPem);
      return;
    }

    // RSA-2048 key generation is synchronous and blocks for ~200–500 ms on
    // first launch. Acceptable for a one-time operation; revisit if janky.
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;

    final csr = X509Utils.generateRsaCsrPem(
      {'CN': 'OneRemote'},
      privateKey,
      publicKey,
    );
    final certPem = X509Utils.generateSelfSignedCertificate(privateKey, csr, 3650);
    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    await Future.wait([
      certFile.writeAsString(certPem),
      keyFile.writeAsString(keyPem),
      rsaFile.writeAsString(jsonEncode({
        'm': publicKey.modulus!.toRadixString(16),
        'e': publicKey.exponent!.toRadixString(16),
      })),
    ]);

    _clientModulus = publicKey.modulus!;
    _clientExponent = publicKey.exponent!;
    _clientContext = _makeContext(certPem, keyPem);
  }

  static SecurityContext _makeContext(String certPem, String keyPem) {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(certPem));
    ctx.usePrivateKeyBytes(utf8.encode(keyPem));
    return ctx;
  }

  /// TLS client context carrying the client cert + private key.
  /// Server certificate trust is handled at connect time by the transport client.
  Future<SecurityContext> get clientContext async {
    await _ensureInitialized();
    return _clientContext!;
  }

  /// RSA public modulus of the client certificate (for pairing secret formula).
  Future<BigInt> get clientModulus async {
    await _ensureInitialized();
    return _clientModulus!;
  }

  /// RSA public exponent of the client certificate (for pairing secret formula).
  Future<BigInt> get clientExponent async {
    await _ensureInitialized();
    return _clientExponent!;
  }

  /// Persists the server's DER-encoded certificate and pre-extracts its RSA
  /// components for later use in [serverRsaComponents].
  Future<void> storeServerCert(String host, Uint8List derBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final tag = _hostTag(host);
    await File('${dir.path}/android_tv_server_$tag.cert.der').writeAsBytes(derBytes);
    final components = _rsaFromCertDer(derBytes);
    if (components != null) {
      final (mod, exp) = components;
      await File('${dir.path}/android_tv_server_$tag.rsa.json').writeAsString(
        jsonEncode({'m': mod.toRadixString(16), 'e': exp.toRadixString(16)}),
      );
    }
  }

  /// Returns the server's RSA (modulus, exponent) for [host], or null if not yet paired.
  Future<(BigInt, BigInt)?> serverRsaComponents(String host) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/android_tv_server_${_hostTag(host)}.rsa.json');
    if (!file.existsSync()) return null;
    final rsa = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (
      BigInt.parse(rsa['m'] as String, radix: 16),
      BigInt.parse(rsa['e'] as String, radix: 16),
    );
  }

  static String _hostTag(String host) =>
      host.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  /// Parses a DER-encoded X.509 certificate and returns the RSA public key's
  /// (modulus, exponent), or null if the cert is not RSA or parsing fails.
  static (BigInt, BigInt)? _rsaFromCertDer(Uint8List der) {
    try {
      final cert = ASN1Parser(der).nextObject() as ASN1Sequence;
      final tbs = cert.elements!.first as ASN1Sequence;

      for (final el in tbs.elements!) {
        if (el is! ASN1Sequence) continue;
        final elems = el.elements;
        if (elems == null || elems.length < 2) continue;
        final algSeq = elems[0];
        if (algSeq is! ASN1Sequence) continue;
        if (algSeq.elements == null || algSeq.elements!.isEmpty) continue;
        final oid = algSeq.elements![0];
        if (oid is! ASN1ObjectIdentifier) continue;
        if (oid.objectIdentifierAsString != '1.2.840.113549.1.1.1') continue;

        // Found SubjectPublicKeyInfo — extract RSA public key from BIT STRING.
        final bitStr = elems[1];
        if (bitStr is! ASN1BitString) continue;
        final rsaDer = Uint8List.fromList(bitStr.stringValues!);
        final rsaSeq = ASN1Parser(rsaDer).nextObject() as ASN1Sequence;
        final mod = (rsaSeq.elements![0] as ASN1Integer).integer!;
        final exp = (rsaSeq.elements![1] as ASN1Integer).integer!;
        return (mod, exp);
      }
    } catch (_) {}
    return null;
  }
}
