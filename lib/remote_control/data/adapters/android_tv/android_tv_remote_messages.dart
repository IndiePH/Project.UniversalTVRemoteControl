import 'package:protobuf/protobuf.dart' as $pb;

// Hand-written GeneratedMessage subclasses for remotemessage.proto (proto3).
// Field numbers and message names are taken verbatim from
// tronikos/androidtvremote2 remotemessage.proto.

// ---------------------------------------------------------------------------
// Enum: RemoteDirection
// ---------------------------------------------------------------------------

class RemoteDirection extends $pb.ProtobufEnum {
  static const RemoteDirection unknownDirection = RemoteDirection._(
    0,
    'UNKNOWN_DIRECTION',
  );
  static const RemoteDirection startLong = RemoteDirection._(1, 'START_LONG');
  static const RemoteDirection endLong = RemoteDirection._(2, 'END_LONG');
  static const RemoteDirection short = RemoteDirection._(3, 'SHORT');

  static const List<RemoteDirection> values = [
    unknownDirection,
    startLong,
    endLong,
    short,
  ];

  static final Map<int, $pb.ProtobufEnum> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static RemoteDirection? valueOf(int value) =>
      _byValue[value] as RemoteDirection?;

  const RemoteDirection._(super.v, super.n);
}

// ---------------------------------------------------------------------------
// RemoteSetActive  (field 2 in RemoteMessage)
// ---------------------------------------------------------------------------

class RemoteSetActive extends $pb.GeneratedMessage {
  factory RemoteSetActive({int? active}) {
    final r = create();
    if (active != null) r.active = active;
    return r;
  }

  RemoteSetActive._() : super();

  factory RemoteSetActive.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteSetActive',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'active', $pb.PbFieldType.O3)
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteSetActive clone() => RemoteSetActive()..mergeFromMessage(this);

  static RemoteSetActive create() => RemoteSetActive._();
  @override
  RemoteSetActive createEmptyInstance() => create();
  static List<RemoteSetActive> createRepeated() => <RemoteSetActive>[];
  static RemoteSetActive? _defaultInstance;
  static RemoteSetActive getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteSetActive>(create);

  int get active => $_getIZ(0);
  set active(int v) => $_setSignedInt32(0, v);
  bool hasActive() => $_has(0);
  void clearActive() => clearField(1);
}

// ---------------------------------------------------------------------------
// RemoteKeyCode  — Android KeyEvent integer constants used in RemoteKeyInject.
// ---------------------------------------------------------------------------

abstract final class RemoteKeyCode {
  static const int home = 3;
  static const int back = 4;
  static const int dpadUp = 19;
  static const int dpadDown = 20;
  static const int dpadLeft = 21;
  static const int dpadRight = 22;
  static const int dpadCenter = 23;
  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int power = 26;
  static const int menu = 82;
  static const int mediaPlayPause = 85;
  static const int volumeMute = 164;
  static const int channelUp = 166;
  static const int channelDown = 167;
  static const int tvPower = 177;
  static const int tvInput = 178;
  static const int explorer = 64;
}

class RemoteKeyInject extends $pb.GeneratedMessage {
  factory RemoteKeyInject({int? keyCode, RemoteDirection? direction}) {
    final r = create();
    if (keyCode != null) r.keyCode = keyCode;
    if (direction != null) r.direction = direction;
    return r;
  }

  RemoteKeyInject._() : super();

  factory RemoteKeyInject.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteKeyInject',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'keyCode', $pb.PbFieldType.O3)
        ..e<RemoteDirection>(
          2,
          'direction',
          $pb.PbFieldType.OE,
          defaultOrMaker: RemoteDirection.unknownDirection,
          valueOf: RemoteDirection.valueOf,
          enumValues: RemoteDirection.values,
        )
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteKeyInject clone() => RemoteKeyInject()..mergeFromMessage(this);

  static RemoteKeyInject create() => RemoteKeyInject._();
  @override
  RemoteKeyInject createEmptyInstance() => create();
  static List<RemoteKeyInject> createRepeated() => <RemoteKeyInject>[];
  static RemoteKeyInject? _defaultInstance;
  static RemoteKeyInject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteKeyInject>(create);

  int get keyCode => $_getIZ(0);
  set keyCode(int v) => $_setSignedInt32(0, v);
  bool hasKeyCode() => $_has(0);
  void clearKeyCode() => clearField(1);

  RemoteDirection get direction =>
      $_getN(1) as RemoteDirection? ?? RemoteDirection.unknownDirection;
  set direction(RemoteDirection v) => setField(2, v);
  bool hasDirection() => $_has(1);
  void clearDirection() => clearField(2);
}

// ---------------------------------------------------------------------------
// RemotePingRequest  (field 8 in RemoteMessage)
// ---------------------------------------------------------------------------

class RemotePingRequest extends $pb.GeneratedMessage {
  factory RemotePingRequest({int? val1, int? val2}) {
    final r = create();
    if (val1 != null) r.val1 = val1;
    if (val2 != null) r.val2 = val2;
    return r;
  }

  RemotePingRequest._() : super();

  factory RemotePingRequest.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemotePingRequest',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'val1', $pb.PbFieldType.O3)
        ..a<int>(2, 'val2', $pb.PbFieldType.O3)
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemotePingRequest clone() => RemotePingRequest()..mergeFromMessage(this);

  static RemotePingRequest create() => RemotePingRequest._();
  @override
  RemotePingRequest createEmptyInstance() => create();
  static List<RemotePingRequest> createRepeated() => <RemotePingRequest>[];
  static RemotePingRequest? _defaultInstance;
  static RemotePingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemotePingRequest>(create);

  int get val1 => $_getIZ(0);
  set val1(int v) => $_setSignedInt32(0, v);
  bool hasVal1() => $_has(0);
  void clearVal1() => clearField(1);

  int get val2 => $_getIZ(1);
  set val2(int v) => $_setSignedInt32(1, v);
  bool hasVal2() => $_has(1);
  void clearVal2() => clearField(2);
}

// ---------------------------------------------------------------------------
// RemotePingResponse  (field 9 in RemoteMessage)
// ---------------------------------------------------------------------------

class RemotePingResponse extends $pb.GeneratedMessage {
  factory RemotePingResponse({int? val1}) {
    final r = create();
    if (val1 != null) r.val1 = val1;
    return r;
  }

  RemotePingResponse._() : super();

  factory RemotePingResponse.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemotePingResponse',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'val1', $pb.PbFieldType.O3)
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemotePingResponse clone() => RemotePingResponse()..mergeFromMessage(this);

  static RemotePingResponse create() => RemotePingResponse._();
  @override
  RemotePingResponse createEmptyInstance() => create();
  static List<RemotePingResponse> createRepeated() => <RemotePingResponse>[];
  static RemotePingResponse? _defaultInstance;
  static RemotePingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemotePingResponse>(create);

  int get val1 => $_getIZ(0);
  set val1(int v) => $_setSignedInt32(0, v);
  bool hasVal1() => $_has(0);
  void clearVal1() => clearField(1);
}

// ---------------------------------------------------------------------------
// RemoteImeObject  — used inside RemoteEditInfo for text sending
// ---------------------------------------------------------------------------

class RemoteImeObject extends $pb.GeneratedMessage {
  factory RemoteImeObject({int? start, int? end, String? value}) {
    final r = create();
    if (start != null) r.start = start;
    if (end != null) r.end = end;
    if (value != null) r.value = value;
    return r;
  }

  RemoteImeObject._() : super();

  factory RemoteImeObject.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteImeObject',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'start', $pb.PbFieldType.O3)
        ..a<int>(2, 'end', $pb.PbFieldType.O3)
        ..aOS(3, 'value')
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteImeObject clone() => RemoteImeObject()..mergeFromMessage(this);

  static RemoteImeObject create() => RemoteImeObject._();
  @override
  RemoteImeObject createEmptyInstance() => create();
  static List<RemoteImeObject> createRepeated() => <RemoteImeObject>[];
  static RemoteImeObject? _defaultInstance;
  static RemoteImeObject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteImeObject>(create);

  int get start => $_getIZ(0);
  set start(int v) => $_setSignedInt32(0, v);
  bool hasStart() => $_has(0);
  void clearStart() => clearField(1);

  int get end => $_getIZ(1);
  set end(int v) => $_setSignedInt32(1, v);
  bool hasEnd() => $_has(1);
  void clearEnd() => clearField(2);

  String get value => $_getSZ(2);
  set value(String v) => $_setString(2, v);
  bool hasValue() => $_has(2);
  void clearValue() => clearField(3);
}

// ---------------------------------------------------------------------------
// RemoteEditInfo  — used inside RemoteImeBatchEdit
// Field name in proto is `text_field_status` but type is RemoteImeObject (not
// RemoteTextFieldStatus — verified against remotemessage.proto source).
// ---------------------------------------------------------------------------

class RemoteEditInfo extends $pb.GeneratedMessage {
  factory RemoteEditInfo({int? insert, RemoteImeObject? textFieldStatus}) {
    final r = create();
    if (insert != null) r.insert = insert;
    if (textFieldStatus != null) r.textFieldStatus = textFieldStatus;
    return r;
  }

  RemoteEditInfo._() : super();

  factory RemoteEditInfo.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteEditInfo',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'insert', $pb.PbFieldType.O3)
        ..aOM<RemoteImeObject>(
          2,
          'textFieldStatus',
          subBuilder: RemoteImeObject.create,
        )
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteEditInfo clone() => RemoteEditInfo()..mergeFromMessage(this);

  static RemoteEditInfo create() => RemoteEditInfo._();
  @override
  RemoteEditInfo createEmptyInstance() => create();
  static List<RemoteEditInfo> createRepeated() => <RemoteEditInfo>[];
  static RemoteEditInfo? _defaultInstance;
  static RemoteEditInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteEditInfo>(create);

  int get insert => $_getIZ(0);
  set insert(int v) => $_setSignedInt32(0, v);
  bool hasInsert() => $_has(0);
  void clearInsert() => clearField(1);

  RemoteImeObject get textFieldStatus => $_getN(1) as RemoteImeObject;
  set textFieldStatus(RemoteImeObject v) => setField(2, v);
  bool hasTextFieldStatus() => $_has(1);
  void clearTextFieldStatus() => clearField(2);
}

// ---------------------------------------------------------------------------
// RemoteImeBatchEdit  (field 21 in RemoteMessage)
// Used to SEND text to the TV and received back to sync IME counters.
// Python send_text: ime_object(start=len-1, end=len-1, value=text),
//   edit_info(insert=1, text_field_status=ime_object),
//   batch_edit(ime_counter, field_counter, edit_info=[edit_info])
// ---------------------------------------------------------------------------

class RemoteImeBatchEdit extends $pb.GeneratedMessage {
  factory RemoteImeBatchEdit({
    int? imeCounter,
    int? fieldCounter,
    List<RemoteEditInfo>? editInfo,
  }) {
    final r = create();
    if (imeCounter != null) r.imeCounter = imeCounter;
    if (fieldCounter != null) r.fieldCounter = fieldCounter;
    if (editInfo != null) r.editInfo.addAll(editInfo);
    return r;
  }

  RemoteImeBatchEdit._() : super();

  factory RemoteImeBatchEdit.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteImeBatchEdit',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'imeCounter', $pb.PbFieldType.O3)
        ..a<int>(2, 'fieldCounter', $pb.PbFieldType.O3)
        ..pc<RemoteEditInfo>(
          3,
          'editInfo',
          $pb.PbFieldType.PM,
          subBuilder: RemoteEditInfo.create,
        )
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteImeBatchEdit clone() => RemoteImeBatchEdit()..mergeFromMessage(this);

  static RemoteImeBatchEdit create() => RemoteImeBatchEdit._();
  @override
  RemoteImeBatchEdit createEmptyInstance() => create();
  static List<RemoteImeBatchEdit> createRepeated() => <RemoteImeBatchEdit>[];
  static RemoteImeBatchEdit? _defaultInstance;
  static RemoteImeBatchEdit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteImeBatchEdit>(create);

  int get imeCounter => $_getIZ(0);
  set imeCounter(int v) => $_setSignedInt32(0, v);
  bool hasImeCounter() => $_has(0);
  void clearImeCounter() => clearField(1);

  int get fieldCounter => $_getIZ(1);
  set fieldCounter(int v) => $_setSignedInt32(1, v);
  bool hasFieldCounter() => $_has(1);
  void clearFieldCounter() => clearField(2);

  List<RemoteEditInfo> get editInfo =>
      $_getList(2) as $pb.PbList<RemoteEditInfo>;
}

// ---------------------------------------------------------------------------
// RemoteTextFieldStatus  — sub-message of RemoteImeKeyInject
// Fields: counterField(1), value(2), start(3), end(4), int5(5), label(6)
// ---------------------------------------------------------------------------

class RemoteTextFieldStatus extends $pb.GeneratedMessage {
  factory RemoteTextFieldStatus({
    int? counterField,
    String? value,
    int? start,
    int? end,
    int? int5,
    String? label,
  }) {
    final r = create();
    if (counterField != null) r.counterField = counterField;
    if (value != null) r.value = value;
    if (start != null) r.start = start;
    if (end != null) r.end = end;
    if (int5 != null) r.int5 = int5;
    if (label != null) r.label = label;
    return r;
  }

  RemoteTextFieldStatus._() : super();

  factory RemoteTextFieldStatus.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteTextFieldStatus',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'counterField', $pb.PbFieldType.O3)
        ..aOS(2, 'value')
        ..a<int>(3, 'start', $pb.PbFieldType.O3)
        ..a<int>(4, 'end', $pb.PbFieldType.O3)
        ..a<int>(5, 'int5', $pb.PbFieldType.O3)
        ..aOS(6, 'label')
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteTextFieldStatus clone() =>
      RemoteTextFieldStatus()..mergeFromMessage(this);

  static RemoteTextFieldStatus create() => RemoteTextFieldStatus._();
  @override
  RemoteTextFieldStatus createEmptyInstance() => create();
  static List<RemoteTextFieldStatus> createRepeated() =>
      <RemoteTextFieldStatus>[];
  static RemoteTextFieldStatus? _defaultInstance;
  static RemoteTextFieldStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteTextFieldStatus>(create);

  int get counterField => $_getIZ(0);
  set counterField(int v) => $_setSignedInt32(0, v);
  bool hasCounterField() => $_has(0);
  void clearCounterField() => clearField(1);

  String get value => $_getSZ(1);
  set value(String v) => $_setString(1, v);
  bool hasValue() => $_has(1);
  void clearValue() => clearField(2);

  int get start => $_getIZ(2);
  set start(int v) => $_setSignedInt32(2, v);
  bool hasStart() => $_has(2);
  void clearStart() => clearField(3);

  int get end => $_getIZ(3);
  set end(int v) => $_setSignedInt32(3, v);
  bool hasEnd() => $_has(3);
  void clearEnd() => clearField(4);

  int get int5 => $_getIZ(4);
  set int5(int v) => $_setSignedInt32(4, v);
  bool hasInt5() => $_has(4);
  void clearInt5() => clearField(5);

  String get label => $_getSZ(5);
  set label(String v) => $_setString(5, v);
  bool hasLabel() => $_has(5);
  void clearLabel() => clearField(6);
}

// ---------------------------------------------------------------------------
// RemoteAppInfo  — sub-message of RemoteImeKeyInject
// Sparse field numbers: 1,2,3,4,7,8,10,12,13
// Indices (BuilderInfo order):  0,1,2,3,4, 5, 6, 7, 8
// ---------------------------------------------------------------------------

class RemoteAppInfo extends $pb.GeneratedMessage {
  factory RemoteAppInfo({String? appPackage, String? label}) {
    final r = create();
    if (appPackage != null) r.appPackage = appPackage;
    if (label != null) r.label = label;
    return r;
  }

  RemoteAppInfo._() : super();

  factory RemoteAppInfo.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteAppInfo',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'counter', $pb.PbFieldType.O3) // index 0
        ..a<int>(2, 'int2', $pb.PbFieldType.O3) // index 1
        ..a<int>(3, 'int3', $pb.PbFieldType.O3) // index 2
        ..aOS(4, 'int4') // index 3
        ..a<int>(7, 'int7', $pb.PbFieldType.O3) // index 4
        ..a<int>(8, 'int8', $pb.PbFieldType.O3) // index 5
        ..aOS(10, 'label') // index 6
        ..aOS(12, 'appPackage') // index 7
        ..a<int>(13, 'int13', $pb.PbFieldType.O3) // index 8
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteAppInfo clone() => RemoteAppInfo()..mergeFromMessage(this);

  static RemoteAppInfo create() => RemoteAppInfo._();
  @override
  RemoteAppInfo createEmptyInstance() => create();
  static List<RemoteAppInfo> createRepeated() => <RemoteAppInfo>[];
  static RemoteAppInfo? _defaultInstance;
  static RemoteAppInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteAppInfo>(create);

  String get label => $_getSZ(6);
  set label(String v) => $_setString(6, v);

  String get appPackage => $_getSZ(7);
  set appPackage(String v) => $_setString(7, v);
  bool hasAppPackage() => $_has(7);
  void clearAppPackage() => clearField(12);
}

// ---------------------------------------------------------------------------
// RemoteImeKeyInject  (field 20 in RemoteMessage)
// INBOUND from TV — carries current app info + text field state.
// The ime_counter/field_counter for outbound text come from inbound
// RemoteImeBatchEdit (field 21), not from this message.
// ---------------------------------------------------------------------------

class RemoteImeKeyInject extends $pb.GeneratedMessage {
  factory RemoteImeKeyInject({
    RemoteAppInfo? appInfo,
    RemoteTextFieldStatus? textFieldStatus,
  }) {
    final r = create();
    if (appInfo != null) r.appInfo = appInfo;
    if (textFieldStatus != null) r.textFieldStatus = textFieldStatus;
    return r;
  }

  RemoteImeKeyInject._() : super();

  factory RemoteImeKeyInject.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteImeKeyInject',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..aOM<RemoteAppInfo>(1, 'appInfo', subBuilder: RemoteAppInfo.create)
        ..aOM<RemoteTextFieldStatus>(
          2,
          'textFieldStatus',
          subBuilder: RemoteTextFieldStatus.create,
        )
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteImeKeyInject clone() => RemoteImeKeyInject()..mergeFromMessage(this);

  static RemoteImeKeyInject create() => RemoteImeKeyInject._();
  @override
  RemoteImeKeyInject createEmptyInstance() => create();
  static List<RemoteImeKeyInject> createRepeated() => <RemoteImeKeyInject>[];
  static RemoteImeKeyInject? _defaultInstance;
  static RemoteImeKeyInject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteImeKeyInject>(create);

  RemoteAppInfo get appInfo => $_getN(0) as RemoteAppInfo;
  set appInfo(RemoteAppInfo v) => setField(1, v);
  bool hasAppInfo() => $_has(0);
  void clearAppInfo() => clearField(1);

  RemoteTextFieldStatus get textFieldStatus =>
      $_getN(1) as RemoteTextFieldStatus;
  set textFieldStatus(RemoteTextFieldStatus v) => setField(2, v);
  bool hasTextFieldStatus() => $_has(1);
  void clearTextFieldStatus() => clearField(2);
}

// ---------------------------------------------------------------------------
// RemoteDeviceInfo  — sub-message of RemoteConfigure
// Sent by both sides during the connection handshake on port 6466.
// ---------------------------------------------------------------------------

class RemoteDeviceInfo extends $pb.GeneratedMessage {
  factory RemoteDeviceInfo({
    String? model,
    String? vendor,
    int? unknown1,
    String? unknown2,
    String? packageName,
    String? appVersion,
  }) {
    final r = create();
    if (model != null) r.model = model;
    if (vendor != null) r.vendor = vendor;
    if (unknown1 != null) r.unknown1 = unknown1;
    if (unknown2 != null) r.unknown2 = unknown2;
    if (packageName != null) r.packageName = packageName;
    if (appVersion != null) r.appVersion = appVersion;
    return r;
  }

  RemoteDeviceInfo._() : super();

  factory RemoteDeviceInfo.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteDeviceInfo',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'model') // index 0
        ..aOS(2, 'vendor') // index 1
        ..a<int>(3, 'unknown1', $pb.PbFieldType.O3) // index 2
        ..aOS(4, 'unknown2') // index 3
        ..aOS(5, 'packageName') // index 4
        ..aOS(6, 'appVersion') // index 5
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteDeviceInfo clone() => RemoteDeviceInfo()..mergeFromMessage(this);

  static RemoteDeviceInfo create() => RemoteDeviceInfo._();
  @override
  RemoteDeviceInfo createEmptyInstance() => create();
  static List<RemoteDeviceInfo> createRepeated() => <RemoteDeviceInfo>[];
  static RemoteDeviceInfo? _defaultInstance;
  static RemoteDeviceInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteDeviceInfo>(create);

  String get model => $_getSZ(0);
  set model(String v) => $_setString(0, v);
  bool hasModel() => $_has(0);
  void clearModel() => clearField(1);

  String get vendor => $_getSZ(1);
  set vendor(String v) => $_setString(1, v);
  bool hasVendor() => $_has(1);
  void clearVendor() => clearField(2);

  int get unknown1 => $_getIZ(2);
  set unknown1(int v) => $_setSignedInt32(2, v);
  bool hasUnknown1() => $_has(2);
  void clearUnknown1() => clearField(3);

  String get unknown2 => $_getSZ(3);
  set unknown2(String v) => $_setString(3, v);
  bool hasUnknown2() => $_has(3);
  void clearUnknown2() => clearField(4);

  String get packageName => $_getSZ(4);
  set packageName(String v) => $_setString(4, v);
  bool hasPackageName() => $_has(4);
  void clearPackageName() => clearField(5);

  String get appVersion => $_getSZ(5);
  set appVersion(String v) => $_setString(5, v);
  bool hasAppVersion() => $_has(5);
  void clearAppVersion() => clearField(6);
}

// ---------------------------------------------------------------------------
// RemoteConfigure  (field 1 in RemoteMessage)
// Server sends this first after TLS connects on port 6466. Client must respond
// with its own RemoteConfigure before the handshake can proceed.
// ---------------------------------------------------------------------------

class RemoteConfigure extends $pb.GeneratedMessage {
  factory RemoteConfigure({int? code1, RemoteDeviceInfo? deviceInfo}) {
    final r = create();
    if (code1 != null) r.code1 = code1;
    if (deviceInfo != null) r.deviceInfo = deviceInfo;
    return r;
  }

  RemoteConfigure._() : super();

  factory RemoteConfigure.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteConfigure',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..a<int>(1, 'code1', $pb.PbFieldType.O3) // index 0
        ..aOM<RemoteDeviceInfo>(
          2,
          'deviceInfo',
          subBuilder: RemoteDeviceInfo.create,
        ) // index 1
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteConfigure clone() => RemoteConfigure()..mergeFromMessage(this);

  static RemoteConfigure create() => RemoteConfigure._();
  @override
  RemoteConfigure createEmptyInstance() => create();
  static List<RemoteConfigure> createRepeated() => <RemoteConfigure>[];
  static RemoteConfigure? _defaultInstance;
  static RemoteConfigure getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteConfigure>(create);

  int get code1 => $_getIZ(0);
  set code1(int v) => $_setSignedInt32(0, v);
  bool hasCode1() => $_has(0);
  void clearCode1() => clearField(1);

  RemoteDeviceInfo get deviceInfo => $_getN(1) as RemoteDeviceInfo;
  set deviceInfo(RemoteDeviceInfo v) => setField(2, v);
  bool hasDeviceInfo() => $_has(1);
  void clearDeviceInfo() => clearField(2);
}

// ---------------------------------------------------------------------------
// RemoteStart  (field 40 in RemoteMessage)
// Server sends this after the RemoteConfigure + RemoteSetActive exchange.
// `started` reflects TV power state (true = on, false = standby).
// Receiving this signals the handshake is complete and commands may be sent.
// ---------------------------------------------------------------------------

class RemoteStart extends $pb.GeneratedMessage {
  factory RemoteStart({bool? started}) {
    final r = create();
    if (started != null) r.started = started;
    return r;
  }

  RemoteStart._() : super();

  factory RemoteStart.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteStart',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..aOB(1, 'started')
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteStart clone() => RemoteStart()..mergeFromMessage(this);

  static RemoteStart create() => RemoteStart._();
  @override
  RemoteStart createEmptyInstance() => create();
  static List<RemoteStart> createRepeated() => <RemoteStart>[];
  static RemoteStart? _defaultInstance;
  static RemoteStart getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteStart>(create);

  bool get started => $_getBF(0);
  set started(bool v) => $_setBool(0, v);
  bool hasStarted() => $_has(0);
  void clearStarted() => clearField(1);
}

// ---------------------------------------------------------------------------
// RemoteAppLinkLaunchRequest  (field 90 in RemoteMessage)
// Launches an app on the Android TV device by deep-link URI.
// app_link is typically 'market://launch?id=<packageName>'.
// ---------------------------------------------------------------------------

class RemoteAppLinkLaunchRequest extends $pb.GeneratedMessage {
  factory RemoteAppLinkLaunchRequest({String? appLink}) {
    final r = create();
    if (appLink != null) r.appLink = appLink;
    return r;
  }

  RemoteAppLinkLaunchRequest._() : super();

  factory RemoteAppLinkLaunchRequest.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteAppLinkLaunchRequest',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'appLink')
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteAppLinkLaunchRequest clone() =>
      RemoteAppLinkLaunchRequest()..mergeFromMessage(this);

  static RemoteAppLinkLaunchRequest create() => RemoteAppLinkLaunchRequest._();
  @override
  RemoteAppLinkLaunchRequest createEmptyInstance() => create();
  static List<RemoteAppLinkLaunchRequest> createRepeated() =>
      <RemoteAppLinkLaunchRequest>[];
  static RemoteAppLinkLaunchRequest? _defaultInstance;
  static RemoteAppLinkLaunchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteAppLinkLaunchRequest>(create);

  String get appLink => $_getSZ(0);
  set appLink(String v) => $_setString(0, v);
  bool hasAppLink() => $_has(0);
  void clearAppLink() => clearField(1);
}

// ---------------------------------------------------------------------------
// RemoteMessage  — top-level wrapper (proto3)
// Only the fields this adapter needs are declared; unknown fields pass through.
//
// Handshake on port 6466 (server speaks first):
//   TV → RemoteConfigure(code1, device_info)
//   App → RemoteConfigure(code1 echo, our device_info)
//   TV → RemoteSetActive(active)
//   App → RemoteSetActive(active echo)
//   TV → RemoteStart(started)   ← connection ready
// ---------------------------------------------------------------------------

class RemoteMessage extends $pb.GeneratedMessage {
  factory RemoteMessage({
    RemoteConfigure? remoteConfigure,
    RemoteSetActive? remoteSetActive,
    RemotePingRequest? remotePingRequest,
    RemotePingResponse? remotePingResponse,
    RemoteKeyInject? remoteKeyInject,
    RemoteImeKeyInject? remoteImeKeyInject,
    RemoteImeBatchEdit? remoteImeBatchEdit,
    RemoteStart? remoteStart,
    RemoteAppLinkLaunchRequest? remoteAppLinkLaunchRequest,
  }) {
    final r = create();
    if (remoteConfigure != null) r.remoteConfigure = remoteConfigure;
    if (remoteSetActive != null) r.remoteSetActive = remoteSetActive;
    if (remotePingRequest != null) r.remotePingRequest = remotePingRequest;
    if (remotePingResponse != null) r.remotePingResponse = remotePingResponse;
    if (remoteKeyInject != null) r.remoteKeyInject = remoteKeyInject;
    if (remoteImeKeyInject != null) r.remoteImeKeyInject = remoteImeKeyInject;
    if (remoteImeBatchEdit != null) r.remoteImeBatchEdit = remoteImeBatchEdit;
    if (remoteStart != null) r.remoteStart = remoteStart;
    if (remoteAppLinkLaunchRequest != null) {
      r.remoteAppLinkLaunchRequest = remoteAppLinkLaunchRequest;
    }
    return r;
  }

  RemoteMessage._() : super();

  factory RemoteMessage.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) => create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'RemoteMessage',
          package: const $pb.PackageName('remote'),
          createEmptyInstance: create,
        )
        ..aOM<RemoteConfigure>(
          1,
          'remoteConfigure',
          subBuilder: RemoteConfigure.create,
        ) // index 0
        ..aOM<RemoteSetActive>(
          2,
          'remoteSetActive',
          subBuilder: RemoteSetActive.create,
        ) // index 1
        ..aOM<RemotePingRequest>(
          8,
          'remotePingRequest',
          subBuilder: RemotePingRequest.create,
        ) // index 2
        ..aOM<RemotePingResponse>(
          9,
          'remotePingResponse',
          subBuilder: RemotePingResponse.create,
        ) // index 3
        ..aOM<RemoteKeyInject>(
          10,
          'remoteKeyInject',
          subBuilder: RemoteKeyInject.create,
        ) // index 4
        ..aOM<RemoteImeKeyInject>(
          20,
          'remoteImeKeyInject',
          subBuilder: RemoteImeKeyInject.create,
        ) // index 5
        ..aOM<RemoteImeBatchEdit>(
          21,
          'remoteImeBatchEdit',
          subBuilder: RemoteImeBatchEdit.create,
        ) // index 6
        ..aOM<RemoteStart>(
          40,
          'remoteStart',
          subBuilder: RemoteStart.create,
        ) // index 7
        ..aOM<RemoteAppLinkLaunchRequest>(
          90,
          'remoteAppLinkLaunchRequest',
          subBuilder: RemoteAppLinkLaunchRequest.create,
        ) // index 8
        ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteMessage clone() => RemoteMessage()..mergeFromMessage(this);

  static RemoteMessage create() => RemoteMessage._();
  @override
  RemoteMessage createEmptyInstance() => create();
  static List<RemoteMessage> createRepeated() => <RemoteMessage>[];
  static RemoteMessage? _defaultInstance;
  static RemoteMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteMessage>(create);

  RemoteConfigure get remoteConfigure => $_getN(0) as RemoteConfigure;
  set remoteConfigure(RemoteConfigure v) => setField(1, v);
  bool hasRemoteConfigure() => $_has(0);
  void clearRemoteConfigure() => clearField(1);

  RemoteSetActive get remoteSetActive => $_getN(1) as RemoteSetActive;
  set remoteSetActive(RemoteSetActive v) => setField(2, v);
  bool hasRemoteSetActive() => $_has(1);
  void clearRemoteSetActive() => clearField(2);

  RemotePingRequest get remotePingRequest => $_getN(2) as RemotePingRequest;
  set remotePingRequest(RemotePingRequest v) => setField(8, v);
  bool hasRemotePingRequest() => $_has(2);
  void clearRemotePingRequest() => clearField(8);

  RemotePingResponse get remotePingResponse => $_getN(3) as RemotePingResponse;
  set remotePingResponse(RemotePingResponse v) => setField(9, v);
  bool hasRemotePingResponse() => $_has(3);
  void clearRemotePingResponse() => clearField(9);

  RemoteKeyInject get remoteKeyInject => $_getN(4) as RemoteKeyInject;
  set remoteKeyInject(RemoteKeyInject v) => setField(10, v);
  bool hasRemoteKeyInject() => $_has(4);
  void clearRemoteKeyInject() => clearField(10);

  RemoteImeKeyInject get remoteImeKeyInject => $_getN(5) as RemoteImeKeyInject;
  set remoteImeKeyInject(RemoteImeKeyInject v) => setField(20, v);
  bool hasRemoteImeKeyInject() => $_has(5);
  void clearRemoteImeKeyInject() => clearField(20);

  RemoteImeBatchEdit get remoteImeBatchEdit => $_getN(6) as RemoteImeBatchEdit;
  set remoteImeBatchEdit(RemoteImeBatchEdit v) => setField(21, v);
  bool hasRemoteImeBatchEdit() => $_has(6);
  void clearRemoteImeBatchEdit() => clearField(21);

  RemoteStart get remoteStart => $_getN(7) as RemoteStart;
  set remoteStart(RemoteStart v) => setField(40, v);
  bool hasRemoteStart() => $_has(7);
  void clearRemoteStart() => clearField(40);

  RemoteAppLinkLaunchRequest get remoteAppLinkLaunchRequest =>
      $_getN(8) as RemoteAppLinkLaunchRequest;
  set remoteAppLinkLaunchRequest(RemoteAppLinkLaunchRequest v) =>
      setField(90, v);
  bool hasRemoteAppLinkLaunchRequest() => $_has(8);
  void clearRemoteAppLinkLaunchRequest() => clearField(90);
}
