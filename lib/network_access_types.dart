import 'dart:convert';
import 'dart:math';

import 'license_entry.dart';

const defaultNetworkPort = 8787;
const defaultNetworkPassword = '88336092';

typedef ReadNetworkHistory = Future<List<SavedLicenseEntry>> Function();
typedef GenerateNetworkLicense =
    Future<SavedLicenseEntry> Function(Map<String, dynamic> input);

class NetworkServerInfo {
  const NetworkServerInfo({
    required this.port,
    required this.urls,
    required this.password,
  });
  final int port;
  final List<String> urls;
  final String password;
}

String createNetworkNonce() {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(24, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
