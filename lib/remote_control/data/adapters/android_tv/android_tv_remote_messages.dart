import 'package:protobuf/protobuf.dart' as $pb;

// Hand-written GeneratedMessage subclasses for remotemessage.proto (proto3).
// Field numbers and message names are taken verbatim from
// tronikos/androidtvremote2 remotemessage.proto.

// ---------------------------------------------------------------------------
// Enum: RemoteDirection
// ---------------------------------------------------------------------------

class RemoteDirection extends $pb.ProtobufEnum {
  static const RemoteDirection unknownDirection =
      RemoteDirection._(0, 'UNKNOWN_DIRECTION');
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemoteSetActive> createRepeated() =>
      $pb.PbList<RemoteSetActive>();
  static RemoteSetActive? _defaultInstance;
  static RemoteSetActive getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteSetActive>(create);

  int get active => $_getIZ(0);
  set active(int v) => $_setSignedInt32(0, v);
  bool hasActive() => $_has(0);
  void clearActive() => clearField(1);
}

// ---------------------------------------------------------------------------
// RemoteKeyInject  (field 10 in RemoteMessage)
// key_code is stored as int32; use RemoteKeyCode constants for values.
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemoteKeyInject> createRepeated() =>
      $pb.PbList<RemoteKeyInject>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemotePingRequest> createRepeated() =>
      $pb.PbList<RemotePingRequest>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemotePingResponse> createRepeated() =>
      $pb.PbList<RemotePingResponse>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemoteImeObject> createRepeated() =>
      $pb.PbList<RemoteImeObject>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'RemoteEditInfo',
    package: const $pb.PackageName('remote'),
    createEmptyInstance: create,
  )
    ..a<int>(1, 'insert', $pb.PbFieldType.O3)
    ..aOM<RemoteImeObject>(2, 'textFieldStatus',
        subBuilder: RemoteImeObject.create)
    ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteEditInfo clone() => RemoteEditInfo()..mergeFromMessage(this);

  static RemoteEditInfo create() => RemoteEditInfo._();
  @override
  RemoteEditInfo createEmptyInstance() => create();
  static $pb.PbList<RemoteEditInfo> createRepeated() =>
      $pb.PbList<RemoteEditInfo>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemoteImeBatchEdit> createRepeated() =>
      $pb.PbList<RemoteImeBatchEdit>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemoteTextFieldStatus> createRepeated() =>
      $pb.PbList<RemoteTextFieldStatus>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'RemoteAppInfo',
    package: const $pb.PackageName('remote'),
    createEmptyInstance: create,
  )
    ..a<int>(1, 'counter', $pb.PbFieldType.O3)    // index 0
    ..a<int>(2, 'int2', $pb.PbFieldType.O3)        // index 1
    ..a<int>(3, 'int3', $pb.PbFieldType.O3)        // index 2
    ..aOS(4, 'int4')                                // index 3
    ..a<int>(7, 'int7', $pb.PbFieldType.O3)        // index 4
    ..a<int>(8, 'int8', $pb.PbFieldType.O3)        // index 5
    ..aOS(10, 'label')                              // index 6
    ..aOS(12, 'appPackage')                         // index 7
    ..a<int>(13, 'int13', $pb.PbFieldType.O3)      // index 8
    ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteAppInfo clone() => RemoteAppInfo()..mergeFromMessage(this);

  static RemoteAppInfo create() => RemoteAppInfo._();
  @override
  RemoteAppInfo createEmptyInstance() => create();
  static $pb.PbList<RemoteAppInfo> createRepeated() =>
      $pb.PbList<RemoteAppInfo>();
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
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
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
  static $pb.PbList<RemoteImeKeyInject> createRepeated() =>
      $pb.PbList<RemoteImeKeyInject>();
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
// RemoteMessage  — top-level wrapper (proto3)
// Only the fields this adapter needs are declared; unknown fields pass through.
// Field 21 (remote_ime_batch_edit) is added beyond the goal-file list because
// it is required for sendText in Task 9 (text is sent via batch_edit, not
// key_inject — verified against Python send_text implementation).
// ---------------------------------------------------------------------------

class RemoteMessage extends $pb.GeneratedMessage {
  factory RemoteMessage({
    RemoteSetActive? remoteSetActive,
    RemotePingRequest? remotePingRequest,
    RemotePingResponse? remotePingResponse,
    RemoteKeyInject? remoteKeyInject,
    RemoteImeKeyInject? remoteImeKeyInject,
    RemoteImeBatchEdit? remoteImeBatchEdit,
  }) {
    final r = create();
    if (remoteSetActive != null) r.remoteSetActive = remoteSetActive;
    if (remotePingRequest != null) r.remotePingRequest = remotePingRequest;
    if (remotePingResponse != null) r.remotePingResponse = remotePingResponse;
    if (remoteKeyInject != null) r.remoteKeyInject = remoteKeyInject;
    if (remoteImeKeyInject != null) r.remoteImeKeyInject = remoteImeKeyInject;
    if (remoteImeBatchEdit != null) r.remoteImeBatchEdit = remoteImeBatchEdit;
    return r;
  }

  RemoteMessage._() : super();

  factory RemoteMessage.fromBuffer(
    List<int> i, [
    $pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY,
  ]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'RemoteMessage',
    package: const $pb.PackageName('remote'),
    createEmptyInstance: create,
  )
    ..aOM<RemoteSetActive>(2, 'remoteSetActive',
        subBuilder: RemoteSetActive.create)                           // index 0
    ..aOM<RemotePingRequest>(8, 'remotePingRequest',
        subBuilder: RemotePingRequest.create)                         // index 1
    ..aOM<RemotePingResponse>(9, 'remotePingResponse',
        subBuilder: RemotePingResponse.create)                        // index 2
    ..aOM<RemoteKeyInject>(10, 'remoteKeyInject',
        subBuilder: RemoteKeyInject.create)                           // index 3
    ..aOM<RemoteImeKeyInject>(20, 'remoteImeKeyInject',
        subBuilder: RemoteImeKeyInject.create)                        // index 4
    ..aOM<RemoteImeBatchEdit>(21, 'remoteImeBatchEdit',
        subBuilder: RemoteImeBatchEdit.create)                        // index 5
    ..hasRequiredFields = false;

  @override
  $pb.BuilderInfo get info_ => _i;

  @override
  RemoteMessage clone() => RemoteMessage()..mergeFromMessage(this);

  static RemoteMessage create() => RemoteMessage._();
  @override
  RemoteMessage createEmptyInstance() => create();
  static $pb.PbList<RemoteMessage> createRepeated() =>
      $pb.PbList<RemoteMessage>();
  static RemoteMessage? _defaultInstance;
  static RemoteMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteMessage>(create);

  RemoteSetActive get remoteSetActive => $_getN(0) as RemoteSetActive;
  set remoteSetActive(RemoteSetActive v) => setField(2, v);
  bool hasRemoteSetActive() => $_has(0);
  void clearRemoteSetActive() => clearField(2);

  RemotePingRequest get remotePingRequest => $_getN(1) as RemotePingRequest;
  set remotePingRequest(RemotePingRequest v) => setField(8, v);
  bool hasRemotePingRequest() => $_has(1);
  void clearRemotePingRequest() => clearField(8);

  RemotePingResponse get remotePingResponse => $_getN(2) as RemotePingResponse;
  set remotePingResponse(RemotePingResponse v) => setField(9, v);
  bool hasRemotePingResponse() => $_has(2);
  void clearRemotePingResponse() => clearField(9);

  RemoteKeyInject get remoteKeyInject => $_getN(3) as RemoteKeyInject;
  set remoteKeyInject(RemoteKeyInject v) => setField(10, v);
  bool hasRemoteKeyInject() => $_has(3);
  void clearRemoteKeyInject() => clearField(10);

  RemoteImeKeyInject get remoteImeKeyInject => $_getN(4) as RemoteImeKeyInject;
  set remoteImeKeyInject(RemoteImeKeyInject v) => setField(20, v);
  bool hasRemoteImeKeyInject() => $_has(4);
  void clearRemoteImeKeyInject() => clearField(20);

  RemoteImeBatchEdit get remoteImeBatchEdit => $_getN(5) as RemoteImeBatchEdit;
  set remoteImeBatchEdit(RemoteImeBatchEdit v) => setField(21, v);
  bool hasRemoteImeBatchEdit() => $_has(5);
  void clearRemoteImeBatchEdit() => clearField(21);
}
