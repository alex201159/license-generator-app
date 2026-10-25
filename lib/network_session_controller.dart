import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_access.dart';

class NetworkSessionController extends ChangeNotifier {
  NetworkSessionController({
    required this.readHistory,
    required this.generateLicense,
    NetworkAccess? access,
  }) : _access = access ?? NetworkAccess();

  final ReadNetworkHistory readHistory;
  final GenerateNetworkLicense generateLicense;
  final NetworkAccess _access;
  NetworkServerInfo? info;
  String? error;
  bool busy = false;
  bool _disposed = false;

  bool get isSupported => _access.isSupported;

  Future<void> start({int port = defaultNetworkPort}) async {
    if (_disposed || busy || info != null || !isSupported) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final started = await _access.start(
        port: port,
        readHistory: readHistory,
        generateLicense: generateLicense,
      );
      if (_disposed) {
        await _access.stop();
        return;
      }
      info = started;
    } catch (_) {
      error =
          'Não foi possível iniciar o servidor. Verifique se a porta está disponível e tente novamente.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_disposed || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _access.stop();
      info = null;
    } catch (_) {
      error = 'Não foi possível encerrar o servidor. Tente novamente.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_access.stop());
    super.dispose();
  }
}
