import 'dart:io';

import 'package:path_provider/path_provider.dart';

class HistoryStorage {
  HistoryStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final directory = await _directory();
    return File('${directory.path}/license_history.json');
  }

  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> write(String contents) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Keep the previous history intact until the new file is fully written.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
