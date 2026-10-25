import 'package:web/web.dart' as web;

class HistoryStorage {
  static const _key = 'license_generator.activation_history.v1';

  Future<String?> read() async => web.window.localStorage.getItem(_key);

  Future<void> write(String contents) async {
    web.window.localStorage.setItem(_key, contents);
  }
}
