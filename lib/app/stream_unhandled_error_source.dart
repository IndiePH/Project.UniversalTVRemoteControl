import 'dart:async';

import 'package:one_remote/app/unhandled_error_source.dart';

final class StreamUnhandledErrorSource implements UnhandledErrorSource {
  final StreamController<Object> _controller =
      StreamController<Object>.broadcast();

  void add(Object error) {
    if (!_controller.isClosed) _controller.add(error);
  }

  @override
  Stream<Object> get errors => _controller.stream;
}
