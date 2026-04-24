import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes Samsung transport debug logs to a local file on-device.
///
/// On Android, it prefers app external files dir so logs can be pulled from:
/// `/storage/emulated/0/Android/data/<package>/files/one_remote_logs/`
class SamsungTransportFileLogger {
  static const bool _enabled = bool.fromEnvironment(
    'SAMSUNG_TRANSPORT_DEBUG',
    defaultValue: true,
  );

  Future<void> _writeChain = Future<void>.value();
  Future<File>? _fileFuture;

  void write(String message) {
    if (!_enabled) {
      return;
    }
    _writeChain = _writeChain.then((_) => _append(message));
  }

  Future<void> _append(String message) async {
    try {
      final file = await (_fileFuture ??= _createFile());
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString(
        '[$timestamp] $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Keep runtime resilient; debug logging must never break transport flow.
    }
  }

  Future<File> _createFile() async {
    final logsDir = await _resolveLogsDirectory();
    await logsDir.create(recursive: true);

    final now = DateTime.now();
    final fileName =
        'samsung_transport_${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}.log';
    final file = File('${logsDir.path}/$fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  static Future<String?> readLatestLogForSharing() async {
    try {
      final logsDir = await _resolveLogsDirectory();
      if (!await logsDir.exists()) {
        return null;
      }
      final files = await logsDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) => file.path.contains('samsung_transport_'))
          .toList();
      if (files.isEmpty) {
        return null;
      }
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      final latest = files.first;
      final content = await latest.readAsString();
      if (content.trim().isEmpty) {
        return null;
      }
      return 'Samsung transport log: ${latest.path}\n\n$content';
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _resolveLogsDirectory() async {
    Directory baseDir;
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      baseDir = externalDir ?? await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }
    return Directory('${baseDir.path}/one_remote_logs');
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
