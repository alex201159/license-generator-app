import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:license_generator_app/history_storage.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('license_history_test_');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  HistoryStorage storage() => HistoryStorage(directory: () async => directory);

  test('Reads saved history from a new storage instance', () async {
    expect(await storage().read(), isNull);
    const first = '[{"customerId":"Cliente São Paulo","code":"abc"}]';
    const updated = '[{"customerId":"Cliente novo","code":"def"}]';
    await storage().write(first);
    expect(await storage().read(), first);
    await storage().write(updated);
    expect(await storage().read(), updated);
    expect(
      await File('${directory.path}/license_history.json.tmp').exists(),
      isFalse,
    );
  });

  test('Preserves saved history if writing the replacement fails', () async {
    await storage().write('previous history');
    await Directory('${directory.path}/license_history.json.tmp').create();
    await expectLater(
      storage().write('new history'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await storage().read(), 'previous history');
  });
}
