import 'dart:convert';

const int dionSyncProtocolVersion = 1;

const String dionSyncMdnsService = '_dionsync._tcp';

const String protocolVersionHeader = 'Dion-Protocol-Version';

class MdnsTxt {
  static const String id = 'id';
  static const String name = 'name';
  static const String pv = 'pv';
  static const String fp = 'fp';
}

class DeviceInfo {
  final String deviceId;
  final String name;
  final int protocolVersion;
  final String certPem;
  final String fingerprint;

  const DeviceInfo({
    required this.deviceId,
    required this.name,
    required this.protocolVersion,
    required this.certPem,
    required this.fingerprint,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'name': name,
    'protocolVersion': protocolVersion,
    'certPem': certPem,
    'fingerprint': fingerprint,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    deviceId: json['deviceId'] as String,
    name: json['name'] as String,
    protocolVersion: json['protocolVersion'] as int,
    certPem: json['certPem'] as String,
    fingerprint: json['fingerprint'] as String,
  );

  String encode() => jsonEncode(toJson());

  factory DeviceInfo.decode(String body) =>
      DeviceInfo.fromJson(jsonDecode(body) as Map<String, dynamic>);
}

/// Body of the [/pair/init] request (A => B) and [/pair/init] response (B => A).
/// On the response [sessionId] identifies the pairing session B created so A
/// can later confirm it; [info] is B's [DeviceInfo].
///
/// On the request, [signature] is the initiator's RSA signature over
/// `canonicalPairingTbs(info)` — proof that the sender holds the private key
/// for [DeviceInfo.certPem], since the pairing client does not present a TLS
/// client certificate. Absent on the response.
class PairInitMessage {
  final DeviceInfo info;
  final String? sessionId;
  final String? signature;

  const PairInitMessage({required this.info, this.sessionId, this.signature});

  Map<String, dynamic> toJson() => {
    'info': info.toJson(),
    if (sessionId != null) 'sessionId': sessionId,
    if (signature != null) 'signature': signature,
  };

  factory PairInitMessage.fromJson(Map<String, dynamic> json) =>
      PairInitMessage(
        info: DeviceInfo.fromJson(json['info'] as Map<String, dynamic>),
        sessionId: json['sessionId'] as String?,
        signature: json['signature'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory PairInitMessage.decode(String body) =>
      PairInitMessage.fromJson(jsonDecode(body) as Map<String, dynamic>);
}

/// Body of the [/pair/confirm] request (A => B).
///
/// [signature] is the initiator's RSA signature over the UTF-8 bytes of
/// [sessionId], proving continued possession of the private key for the cert
/// bound to the pairing session.
class PairConfirmMessage {
  final String sessionId;
  final bool accept;
  final String? signature;

  const PairConfirmMessage({
    required this.sessionId,
    required this.accept,
    this.signature,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'accept': accept,
    if (signature != null) 'signature': signature,
  };

  factory PairConfirmMessage.fromJson(Map<String, dynamic> json) =>
      PairConfirmMessage(
        sessionId: json['sessionId'] as String,
        accept: json['accept'] as bool,
        signature: json['signature'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory PairConfirmMessage.decode(String body) =>
      PairConfirmMessage.fromJson(jsonDecode(body) as Map<String, dynamic>);
}

/// Body of the [/pair/confirm] response (B => A).
class PairConfirmResult {
  final bool paired;
  final String? error;

  const PairConfirmResult({required this.paired, this.error});

  Map<String, dynamic> toJson() => {
    'paired': paired,
    if (error != null) 'error': error,
  };

  factory PairConfirmResult.fromJson(Map<String, dynamic> json) =>
      PairConfirmResult(
        paired: json['paired'] as bool,
        error: json['error'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory PairConfirmResult.decode(String body) =>
      PairConfirmResult.fromJson(jsonDecode(body) as Map<String, dynamic>);
}
