import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:dionysos/service/lansync/protocol.dart';

Uint8List canonicalPairingTbs(DeviceInfo info) {
  return Uint8List.fromList(utf8.encode(jsonEncode(info.toJson())));
}

String signPayload(String privateKeyPem, Uint8List data) {
  final key = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
  final sig = CryptoUtils.rsaSign(key, data);
  return base64.encode(sig);
}

bool verifyPayload(String certPem, Uint8List data, String signatureBase64) {
  try {
    final cert = X509Utils.x509CertificateFromPem(certPem);
    final spkiHex = cert.tbsCertificate?.subjectPublicKeyInfo.bytes;
    if (spkiHex == null) return false;
    final publicKey = CryptoUtils.rsaPublicKeyFromDERBytes(
      HexUtils.decode(spkiHex),
    );
    final signature = base64.decode(signatureBase64);
    return CryptoUtils.rsaVerify(publicKey, data, Uint8List.fromList(signature));
  } catch (_) {
    return false;
  }
}
