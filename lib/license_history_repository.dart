import 'dart:convert';

import 'history_storage.dart';
import 'license_entry.dart';

class LicenseHistoryRepository {
  LicenseHistoryRepository(this.storage);

  final HistoryStorage storage;
  Future<void> _pendingWrite = Future<void>.value();

  Future<List<SavedLicenseEntry>> load() async {
    final contents = await storage.read();
    if (contents == null) return [];
    return (jsonDecode(contents) as List<dynamic>)
        .map(
          (entry) => SavedLicenseEntry.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<SavedLicenseEntry>> add(SavedLicenseEntry entry) {
    // Native and browser requests share this queue. Read the latest committed
    // history inside the transaction so simultaneous generations cannot replace
    // each other's records with an older snapshot.
    final operation = _pendingWrite.then((_) async {
      final entries = [entry, ...await load()];
      await storage.write(jsonEncode(entries));
      return entries;
    });
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }
}
