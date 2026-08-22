import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/android_tv/android_tv_remote_messages.dart';

void main() {
  group('RemoteImeBatchEdit.editInfo', () {
    test('reads back a repeated RemoteEditInfo without a cast error', () {
      final imeObject = RemoteImeObject(start: 2, end: 2, value: 'abc');
      final editInfo = RemoteEditInfo(insert: 1, textFieldStatus: imeObject);
      final batchEdit = RemoteImeBatchEdit(
        imeCounter: 1,
        fieldCounter: 1,
        editInfo: [editInfo],
      );

      expect(batchEdit.editInfo, hasLength(1));
      expect(batchEdit.editInfo.single.insert, 1);
      expect(batchEdit.editInfo.single.textFieldStatus.value, 'abc');
    });

    test('survives a serialize/deserialize round trip', () {
      final imeObject = RemoteImeObject(start: 2, end: 2, value: 'hello');
      final editInfo = RemoteEditInfo(insert: 1, textFieldStatus: imeObject);
      final batchEdit = RemoteImeBatchEdit(
        imeCounter: 3,
        fieldCounter: 4,
        editInfo: [editInfo],
      );

      final message = RemoteMessage(remoteImeBatchEdit: batchEdit);
      final decoded = RemoteMessage.fromBuffer(message.writeToBuffer());

      expect(decoded.remoteImeBatchEdit.editInfo, hasLength(1));
      expect(
        decoded.remoteImeBatchEdit.editInfo.single.textFieldStatus.value,
        'hello',
      );
    });
  });
}
