import 'package:protobuf/protobuf.dart' as $pb;

// Hand-written GeneratedMessage subclasses for polo.proto (proto2).
// Field numbers, required/optional modifiers, and message names are taken
// verbatim from tronikos/androidtvremote2 polo.proto.

// ---------------------------------------------------------------------------
// Enum: PairingStatus  (nested in OuterMessage.Status in proto, flattened here)
// ---------------------------------------------------------------------------

class PairingStatus extends $pb.ProtobufEnum {
  static const PairingStatus statusOk = PairingStatus._(200, 'STATUS_OK');
  static const PairingStatus statusError =
      PairingStatus._(400, 'STATUS_ERROR');
  static const PairingStatus statusBadConfiguration =
      PairingStatus._(401, 'STATUS_BAD_CONFIGURATION');
  static const PairingStatus statusBadSecret =
      PairingStatus._(402, 'STATUS_BAD_SECRET');

  static const List<PairingStatus> values = [
    statusOk,
    statusError,
    statusBadConfiguration,
    statusBadSecret,
  ];

  static final Map<int, $pb.ProtobufEnum> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static PairingStatus? valueOf(int value) =>
      _byValue[value] as PairingStatus?;

  const PairingStatus._(super.v, super.n);
}

// ---------------------------------------------------------------------------
// Enum: EncodingType  (nested in Options.Encoding in proto, flattened here)
// ---------------------------------------------------------------------------

class EncodingType extends $pb.ProtobufEnum {
  static const EncodingType unknown =
      EncodingType._(0, 'ENCODING_TYPE_UNKNOWN');
  static const EncodingType alphanumeric =
      EncodingType._(1, 'ENCODING_TYPE_ALPHANUMERIC');
  static const EncodingType numeric =
      EncodingType._(2, 'ENCODING_TYPE_NUMERIC');
  static const EncodingType hexadecimal =
      EncodingType._(3, 'ENCODING_TYPE_HEXADECIMAL');
  static const EncodingType qrCode =
      EncodingType._(4, 'ENCODING_TYPE_QRCODE');

  static const List<EncodingType> values = [
    unknown,
    alphanumeric,
    numeric,
    hexadecimal,
    qrCode,
  ];

  static final Map<int, $pb.ProtobufEnum> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static EncodingType? valueOf(int value) =>
      _byValue[value] as EncodingType?;

  const EncodingType._(super.v, super.n);
}

// ---------------------------------------------------------------------------
// Enum: RoleType
// ---------------------------------------------------------------------------

class RoleType extends $pb.ProtobufEnum {
  static const RoleType unknown = RoleType._(0, 'ROLE_TYPE_UNKNOWN');
  static const RoleType input = RoleType._(1, 'ROLE_TYPE_INPUT');
  static const RoleType output = RoleType._(2, 'ROLE_TYPE_OUTPUT');

  static const List<RoleType> values = [unknown, input, output];

  static final Map<int, $pb.ProtobufEnum> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static RoleType? valueOf(int value) => _byValue[value] as RoleType?;

  const RoleType._(super.v, super.n);
}

// ---------------------------------------------------------------------------
// OptionsEncoding  (Options.Encoding in proto)
// required fields: type (1), symbol_length (2)
// ---------------------------------------------------------------------------

class OptionsEncoding extends $pb.GeneratedMessage {
  factory OptionsEncoding({EncodingType? type, int? symbolLength}) {
    final r = create();
    if (type != null) r.type = type;
    if (symbolLength != null) r.symbolLength = symbolLength;
    return r;
  }

  OptionsEncoding._() : super();

  factory OptionsEncoding.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'Options.Encoding',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )
    ..e<EncodingType>(
      1,
      'type',
      $pb.PbFieldType.QE,
      defaultOrMaker: EncodingType.unknown,
      valueOf: EncodingType.valueOf,
      enumValues: EncodingType.values,
    )
    ..a<int>(2, 'symbolLength', $pb.PbFieldType.Q3);

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  OptionsEncoding clone() => OptionsEncoding()..mergeFromMessage(this);

  static OptionsEncoding create() => OptionsEncoding._();
  @override
  OptionsEncoding createEmptyInstance() => create();
  static $pb.PbList<OptionsEncoding> createRepeated() =>
      $pb.PbList<OptionsEncoding>();
  static OptionsEncoding? _defaultInstance;
  static OptionsEncoding getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OptionsEncoding>(create);

  EncodingType get type =>
      $_getN(0) as EncodingType? ?? EncodingType.unknown;
  set type(EncodingType v) => setField(1, v);
  bool hasType() => $_has(0);
  void clearType() => clearField(1);

  int get symbolLength => $_getIZ(1);
  set symbolLength(int v) => $_setSignedInt32(1, v);
  bool hasSymbolLength() => $_has(1);
  void clearSymbolLength() => clearField(2);
}

// ---------------------------------------------------------------------------
// PairingRequest
// required: service_name (1); optional: client_name (2)
// ---------------------------------------------------------------------------

class PairingRequest extends $pb.GeneratedMessage {
  factory PairingRequest({String? serviceName, String? clientName}) {
    final r = create();
    if (serviceName != null) r.serviceName = serviceName;
    if (clientName != null) r.clientName = clientName;
    return r;
  }

  PairingRequest._() : super();

  factory PairingRequest.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'PairingRequest',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )
    ..a<String>(1, 'serviceName', $pb.PbFieldType.QS)
    ..aOS(2, 'clientName');

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  PairingRequest clone() => PairingRequest()..mergeFromMessage(this);

  static PairingRequest create() => PairingRequest._();
  @override
  PairingRequest createEmptyInstance() => create();
  static $pb.PbList<PairingRequest> createRepeated() =>
      $pb.PbList<PairingRequest>();
  static PairingRequest? _defaultInstance;
  static PairingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairingRequest>(create);

  String get serviceName => $_getSZ(0);
  set serviceName(String v) => $_setString(0, v);
  bool hasServiceName() => $_has(0);
  void clearServiceName() => clearField(1);

  String get clientName => $_getSZ(1);
  set clientName(String v) => $_setString(1, v);
  bool hasClientName() => $_has(1);
  void clearClientName() => clearField(2);
}

// ---------------------------------------------------------------------------
// PairingRequestAck
// optional: server_name (1)
// ---------------------------------------------------------------------------

class PairingRequestAck extends $pb.GeneratedMessage {
  factory PairingRequestAck({String? serverName}) {
    final r = create();
    if (serverName != null) r.serverName = serverName;
    return r;
  }

  PairingRequestAck._() : super();

  factory PairingRequestAck.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'PairingRequestAck',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )
    ..aOS(1, 'serverName')
    ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  PairingRequestAck clone() => PairingRequestAck()..mergeFromMessage(this);

  static PairingRequestAck create() => PairingRequestAck._();
  @override
  PairingRequestAck createEmptyInstance() => create();
  static $pb.PbList<PairingRequestAck> createRepeated() =>
      $pb.PbList<PairingRequestAck>();
  static PairingRequestAck? _defaultInstance;
  static PairingRequestAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairingRequestAck>(create);

  String get serverName => $_getSZ(0);
  set serverName(String v) => $_setString(0, v);
  bool hasServerName() => $_has(0);
  void clearServerName() => clearField(1);
}

// ---------------------------------------------------------------------------
// Options
// repeated: input_encodings (1), output_encodings (2)
// optional: preferred_role (3)
// ---------------------------------------------------------------------------

class Options extends $pb.GeneratedMessage {
  factory Options({
    List<OptionsEncoding>? inputEncodings,
    List<OptionsEncoding>? outputEncodings,
    RoleType? preferredRole,
  }) {
    final r = create();
    if (inputEncodings != null) r.inputEncodings.addAll(inputEncodings);
    if (outputEncodings != null) r.outputEncodings.addAll(outputEncodings);
    if (preferredRole != null) r.preferredRole = preferredRole;
    return r;
  }

  Options._() : super();

  factory Options.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'Options',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )
    ..pc<OptionsEncoding>(
      1,
      'inputEncodings',
      $pb.PbFieldType.PM,
      subBuilder: OptionsEncoding.create,
    )
    ..pc<OptionsEncoding>(
      2,
      'outputEncodings',
      $pb.PbFieldType.PM,
      subBuilder: OptionsEncoding.create,
    )
    ..e<RoleType>(
      3,
      'preferredRole',
      $pb.PbFieldType.OE,
      defaultOrMaker: RoleType.unknown,
      valueOf: RoleType.valueOf,
      enumValues: RoleType.values,
    )
    ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  Options clone() => Options()..mergeFromMessage(this);

  static Options create() => Options._();
  @override
  Options createEmptyInstance() => create();
  static $pb.PbList<Options> createRepeated() => $pb.PbList<Options>();
  static Options? _defaultInstance;
  static Options getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Options>(create);

  List<OptionsEncoding> get inputEncodings => $_getList(0);
  List<OptionsEncoding> get outputEncodings => $_getList(1);

  RoleType get preferredRole => $_getN(2) as RoleType? ?? RoleType.unknown;
  set preferredRole(RoleType v) => setField(3, v);
  bool hasPreferredRole() => $_has(2);
  void clearPreferredRole() => clearField(3);
}

// ---------------------------------------------------------------------------
// Configuration
// required: encoding (1), client_role (2)
// ---------------------------------------------------------------------------

class Configuration extends $pb.GeneratedMessage {
  factory Configuration({OptionsEncoding? encoding, RoleType? clientRole}) {
    final r = create();
    if (encoding != null) r.encoding = encoding;
    if (clientRole != null) r.clientRole = clientRole;
    return r;
  }

  Configuration._() : super();

  factory Configuration.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'Configuration',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )
    ..aOM<OptionsEncoding>(1, 'encoding', subBuilder: OptionsEncoding.create)
    ..e<RoleType>(
      2,
      'clientRole',
      $pb.PbFieldType.QE,
      defaultOrMaker: RoleType.unknown,
      valueOf: RoleType.valueOf,
      enumValues: RoleType.values,
    );

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  Configuration clone() => Configuration()..mergeFromMessage(this);

  static Configuration create() => Configuration._();
  @override
  Configuration createEmptyInstance() => create();
  static $pb.PbList<Configuration> createRepeated() =>
      $pb.PbList<Configuration>();
  static Configuration? _defaultInstance;
  static Configuration getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Configuration>(create);

  OptionsEncoding get encoding => $_getN(0) as OptionsEncoding;
  set encoding(OptionsEncoding v) => setField(1, v);
  bool hasEncoding() => $_has(0);
  void clearEncoding() => clearField(1);

  RoleType get clientRole => $_getN(1) as RoleType? ?? RoleType.unknown;
  set clientRole(RoleType v) => setField(2, v);
  bool hasClientRole() => $_has(1);
  void clearClientRole() => clearField(2);
}

// ---------------------------------------------------------------------------
// ConfigurationAck  — empty message
// ---------------------------------------------------------------------------

class ConfigurationAck extends $pb.GeneratedMessage {
  factory ConfigurationAck() => create();

  ConfigurationAck._() : super();

  factory ConfigurationAck.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'ConfigurationAck',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  ConfigurationAck clone() => ConfigurationAck()..mergeFromMessage(this);

  static ConfigurationAck create() => ConfigurationAck._();
  @override
  ConfigurationAck createEmptyInstance() => create();
  static $pb.PbList<ConfigurationAck> createRepeated() =>
      $pb.PbList<ConfigurationAck>();
  static ConfigurationAck? _defaultInstance;
  static ConfigurationAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfigurationAck>(create);
}

// ---------------------------------------------------------------------------
// Secret  — required bytes field (1)
// ---------------------------------------------------------------------------

class Secret extends $pb.GeneratedMessage {
  factory Secret({List<int>? secret}) {
    final r = create();
    if (secret != null) r.secret = secret;
    return r;
  }

  Secret._() : super();

  factory Secret.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'Secret',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )..a<List<int>>(1, 'secret', $pb.PbFieldType.QY);

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  Secret clone() => Secret()..mergeFromMessage(this);

  static Secret create() => Secret._();
  @override
  Secret createEmptyInstance() => create();
  static $pb.PbList<Secret> createRepeated() => $pb.PbList<Secret>();
  static Secret? _defaultInstance;
  static Secret getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Secret>(create);

  List<int> get secret => $_getN(0) as List<int>? ?? const [];
  set secret(List<int> v) => setField(1, v);
  bool hasSecret() => $_has(0);
  void clearSecret() => clearField(1);
}

// ---------------------------------------------------------------------------
// SecretAck  — required bytes field (1)
// ---------------------------------------------------------------------------

class SecretAck extends $pb.GeneratedMessage {
  factory SecretAck({List<int>? secret}) {
    final r = create();
    if (secret != null) r.secret = secret;
    return r;
  }

  SecretAck._() : super();

  factory SecretAck.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'SecretAck',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )..a<List<int>>(1, 'secret', $pb.PbFieldType.QY);

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  SecretAck clone() => SecretAck()..mergeFromMessage(this);

  static SecretAck create() => SecretAck._();
  @override
  SecretAck createEmptyInstance() => create();
  static $pb.PbList<SecretAck> createRepeated() => $pb.PbList<SecretAck>();
  static SecretAck? _defaultInstance;
  static SecretAck getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SecretAck>(create);

  List<int> get secret => $_getN(0) as List<int>? ?? const [];
  set secret(List<int> v) => setField(1, v);
  bool hasSecret() => $_has(0);
  void clearSecret() => clearField(1);
}

// ---------------------------------------------------------------------------
// OuterMessage  — top-level pairing wrapper (proto2)
// required: protocol_version (1, default=1), status (2)
// optional phase fields: pairing_request(10), pairing_request_ack(11),
//   options(20), configuration(30), configuration_ack(31),
//   secret(40), secret_ack(41)
// ---------------------------------------------------------------------------

class OuterMessage extends $pb.GeneratedMessage {
  factory OuterMessage({
    int? protocolVersion,
    PairingStatus? status,
    PairingRequest? pairingRequest,
    PairingRequestAck? pairingRequestAck,
    Options? options,
    Configuration? configuration,
    ConfigurationAck? configurationAck,
    Secret? secret,
    SecretAck? secretAck,
  }) {
    final r = create();
    if (protocolVersion != null) r.protocolVersion = protocolVersion;
    if (status != null) r.status = status;
    if (pairingRequest != null) r.pairingRequest = pairingRequest;
    if (pairingRequestAck != null) r.pairingRequestAck = pairingRequestAck;
    if (options != null) r.options = options;
    if (configuration != null) r.configuration = configuration;
    if (configurationAck != null) r.configurationAck = configurationAck;
    if (secret != null) r.secret = secret;
    if (secretAck != null) r.secretAck = secretAck;
    return r;
  }

  OuterMessage._() : super();

  factory OuterMessage.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'OuterMessage',
    package: const $pb.PackageName('polo.wire.protobuf'),
    createEmptyInstance: create,
  )
    ..a<int>(1, 'protocolVersion', $pb.PbFieldType.QU3,
        defaultOrMaker: 1)                                            // index 0
    ..e<PairingStatus>(
      2,
      'status',
      $pb.PbFieldType.QE,
      defaultOrMaker: PairingStatus.statusOk,
      valueOf: PairingStatus.valueOf,
      enumValues: PairingStatus.values,
    )                                                                 // index 1
    ..aOM<PairingRequest>(10, 'pairingRequest',
        subBuilder: PairingRequest.create)                            // index 2
    ..aOM<PairingRequestAck>(11, 'pairingRequestAck',
        subBuilder: PairingRequestAck.create)                         // index 3
    ..aOM<Options>(20, 'options', subBuilder: Options.create)         // index 4
    ..aOM<Configuration>(30, 'configuration',
        subBuilder: Configuration.create)                             // index 5
    ..aOM<ConfigurationAck>(31, 'configurationAck',
        subBuilder: ConfigurationAck.create)                          // index 6
    ..aOM<Secret>(40, 'secret', subBuilder: Secret.create)            // index 7
    ..aOM<SecretAck>(41, 'secretAck', subBuilder: SecretAck.create);  // index 8

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  OuterMessage clone() => OuterMessage()..mergeFromMessage(this);

  static OuterMessage create() => OuterMessage._();
  @override
  OuterMessage createEmptyInstance() => create();
  static $pb.PbList<OuterMessage> createRepeated() =>
      $pb.PbList<OuterMessage>();
  static OuterMessage? _defaultInstance;
  static OuterMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OuterMessage>(create);

  int get protocolVersion => $_getIZ(0);
  set protocolVersion(int v) => $_setUnsignedInt32(0, v);
  bool hasProtocolVersion() => $_has(0);
  void clearProtocolVersion() => clearField(1);

  PairingStatus get status =>
      $_getN(1) as PairingStatus? ?? PairingStatus.statusOk;
  set status(PairingStatus v) => setField(2, v);
  bool hasStatus() => $_has(1);
  void clearStatus() => clearField(2);

  PairingRequest get pairingRequest => $_getN(2) as PairingRequest;
  set pairingRequest(PairingRequest v) => setField(10, v);
  bool hasPairingRequest() => $_has(2);
  void clearPairingRequest() => clearField(10);

  PairingRequestAck get pairingRequestAck => $_getN(3) as PairingRequestAck;
  set pairingRequestAck(PairingRequestAck v) => setField(11, v);
  bool hasPairingRequestAck() => $_has(3);
  void clearPairingRequestAck() => clearField(11);

  Options get options => $_getN(4) as Options;
  set options(Options v) => setField(20, v);
  bool hasOptions() => $_has(4);
  void clearOptions() => clearField(20);

  Configuration get configuration => $_getN(5) as Configuration;
  set configuration(Configuration v) => setField(30, v);
  bool hasConfiguration() => $_has(5);
  void clearConfiguration() => clearField(30);

  ConfigurationAck get configurationAck => $_getN(6) as ConfigurationAck;
  set configurationAck(ConfigurationAck v) => setField(31, v);
  bool hasConfigurationAck() => $_has(6);
  void clearConfigurationAck() => clearField(31);

  Secret get secret => $_getN(7) as Secret;
  set secret(Secret v) => setField(40, v);
  bool hasSecret() => $_has(7);
  void clearSecret() => clearField(40);

  SecretAck get secretAck => $_getN(8) as SecretAck;
  set secretAck(SecretAck v) => setField(41, v);
  bool hasSecretAck() => $_has(8);
  void clearSecretAck() => clearField(41);
}
