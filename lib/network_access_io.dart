import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'network_access_types.dart';
import 'network_dashboard.dart';

class NetworkAccess {
  HttpServer? _server;
  bool get isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<NetworkServerInfo> start({
    int port = defaultNetworkPort,
    required ReadNetworkHistory readHistory,
    required GenerateNetworkLicense generateLicense,
    InternetAddress? address,
  }) async {
    if (_server != null) throw StateError('O acesso pela rede já está ativo.');
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final localAddresses = interfaces
        .expand((item) => item.addresses)
        .where((item) => !item.isLoopback && !item.isLinkLocal)
        .map((item) => item.address)
        .toSet();
    const password = defaultNetworkPassword;
    final nonce = createNetworkNonce();
    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    _server = server;
    server.idleTimeout = const Duration(seconds: 30);
    final allowedHosts = {
      'localhost',
      '127.0.0.1',
      Platform.localHostname.toLowerCase(),
      ...localAddresses,
    };
    server.listen(
      (request) => unawaited(
        _handle(
          request,
          password: password,
          nonce: nonce,
          port: server.port,
          allowedHosts: allowedHosts,
          readHistory: readHistory,
          generateLicense: generateLicense,
        ),
      ),
    );
    return NetworkServerInfo(
      port: server.port,
      urls:
          (localAddresses.isEmpty ? ['127.0.0.1'] : localAddresses.toList()
                ..sort())
              .map((host) => 'http://$host:${server.port}')
              .toList(),
      password: password,
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  bool _validPassword(String provided, String password) {
    final a = utf8.encode(provided);
    final b = utf8.encode(password);
    var difference = a.length ^ b.length;
    for (var i = 0; i < b.length; i++) {
      difference |= (i < a.length ? a[i] : 0) ^ b[i];
    }
    return difference == 0;
  }

  void _json(HttpResponse response, int status, Object data) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
  }

  Future<void> _handle(
    HttpRequest request, {
    required String password,
    required String nonce,
    required int port,
    required Set<String> allowedHosts,
    required ReadNetworkHistory readHistory,
    required GenerateNetworkLicense generateLicense,
  }) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('X-Frame-Options', 'DENY')
      ..set('Referrer-Policy', 'no-referrer')
      ..set(
        'Content-Security-Policy',
        "default-src 'self'; script-src 'nonce-$nonce'; style-src 'nonce-$nonce'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
      );
    try {
      final host = Uri.tryParse(
        'http://${request.headers.value(HttpHeaders.hostHeader) ?? ''}',
      );
      if (host == null ||
          host.userInfo.isNotEmpty ||
          !allowedHosts.contains(host.host.toLowerCase()) ||
          host.port != port) {
        _json(response, HttpStatus.forbidden, {
          'error': 'Endereço de acesso não permitido.',
        });
        return;
      }
      final origin = request.headers.value('origin');
      if (origin != null && origin != host.origin) {
        _json(response, HttpStatus.forbidden, {
          'error': 'Origem de acesso não permitida.',
        });
        return;
      }
      final path = request.uri.path;
      if (path == '/' &&
          (request.method == 'GET' || request.method == 'HEAD')) {
        response.headers.contentType = ContentType.html;
        if (request.method != 'HEAD') {
          response.write(networkDashboardHtml.replaceAll('__NONCE__', nonce));
        }
        return;
      }
      if (path != '/api/history' && path != '/api/licenses') {
        _json(response, HttpStatus.notFound, {
          'error': 'Página não encontrada.',
        });
        return;
      }
      final authorization =
          request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (authorization.length > 512 ||
          !authorization.startsWith('Bearer ') ||
          !_validPassword(authorization.substring(7), password)) {
        _json(response, HttpStatus.unauthorized, {
          'error': 'Senha de acesso incorreta.',
        });
        return;
      }
      if (path == '/api/history' && request.method == 'GET') {
        _json(response, HttpStatus.ok, {
          'entries': await readHistory(),
          'serverTime': DateTime.now().toUtc().toIso8601String(),
        });
      } else if (path == '/api/licenses' && request.method == 'POST') {
        if (request.headers.contentType?.mimeType != 'application/json') {
          _json(response, HttpStatus.unsupportedMediaType, {
            'error': 'Envie os dados em formato JSON.',
          });
          return;
        }
        final bytes = <int>[];
        var oversized = false;
        await for (final chunk in request) {
          if (oversized) continue;
          if (bytes.length + chunk.length > 8192) {
            oversized = true;
            bytes.clear();
          } else {
            bytes.addAll(chunk);
          }
        }
        // Drain the body before responding. Canceling its stream midway can
        // reset the Windows socket before the browser receives the HTTP 413.
        if (oversized) {
          _json(response, HttpStatus.requestEntityTooLarge, {
            'error': 'Os dados enviados são muito longos.',
          });
          return;
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Dados de ativação inválidos.');
        }
        final entry = await generateLicense(data);
        _json(response, HttpStatus.created, entry);
      } else {
        response.headers.set(
          HttpHeaders.allowHeader,
          path == '/api/history' ? 'GET' : 'POST',
        );
        _json(response, HttpStatus.methodNotAllowed, {
          'error': 'Operação não permitida.',
        });
      }
    } on FormatException catch (error) {
      _json(response, HttpStatus.badRequest, {'error': error.message});
    } catch (_) {
      _json(response, HttpStatus.internalServerError, {
        'error':
            'Não foi possível acessar ou salvar os dados no computador. Tente novamente.',
      });
    } finally {
      try {
        await response.close();
      } on IOException {
        // A browser may disconnect while a request is being processed.
      }
    }
  }
}
