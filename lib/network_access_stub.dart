import 'network_access_types.dart';

class NetworkAccess {
  bool get isSupported => false;

  Future<NetworkServerInfo> start({
    int port = defaultNetworkPort,
    required ReadNetworkHistory readHistory,
    required GenerateNetworkLicense generateLicense,
  }) async => throw UnsupportedError(
    'Ative o acesso pelo aplicativo instalado no computador.',
  );

  Future<void> stop() async {}
}
