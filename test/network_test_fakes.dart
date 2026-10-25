import 'dart:io';

import 'package:license_generator_app/network_access.dart';

class FakeNetworkAccess extends NetworkAccess {
  bool running = false;
  int startCount = 0;
  NetworkServerInfo? info;

  @override
  bool get isSupported => true;

  @override
  Future<NetworkServerInfo> start({
    int port = defaultNetworkPort,
    required ReadNetworkHistory readHistory,
    required GenerateNetworkLicense generateLicense,
    InternetAddress? address,
  }) async {
    running = true;
    startCount++;
    return info = NetworkServerInfo(
      port: port,
      urls: ['http://192.168.1.10:$port'],
      password: defaultNetworkPassword,
    );
  }

  @override
  Future<void> stop() async {
    running = false;
  }
}
