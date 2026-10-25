import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_generator_app/history_storage.dart';
import 'package:license_generator_app/license_entry.dart';
import 'package:license_generator_app/license_history_repository.dart';
import 'package:license_generator_app/license_service.dart';
import 'package:license_generator_app/network_access_io.dart';
import 'package:license_generator_app/network_access_types.dart';

void main() {
  late Directory directory;
  late LicenseHistoryRepository repository;
  late NetworkAccess access;
  late NetworkServerInfo info;
  late HttpClient client;
  const secret = 'test-signing-secret';

  Future<SavedLicenseEntry> generate(Map<String, dynamic> input) async {
    final entry = generateLicenseFromRequest(
      input,
      secret: secret,
      now: DateTime.utc(2026, 10, 25, 16, 39, 18),
    );
    await repository.add(entry);
    return entry;
  }

  Future<({int status, String body, HttpHeaders headers})> request(
    String path, {
    String method = 'GET',
    Object? body,
    bool authenticated = true,
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${info.port}$path'),
    );
    if (authenticated) {
      request.headers.set('Authorization', 'Bearer ${info.password}');
    }
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
      headers: response.headers,
    );
  }

  Map<String, dynamic> input(String customer) => {
    'customerId': customer,
    'hardwareId': 'AA-BB-CC-DD',
    'months': 5,
    'amount': '1.234,56',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('license_network_test_');
    repository = LicenseHistoryRepository(
      HistoryStorage(directory: () async => directory),
    );
    access = NetworkAccess();
    info = await access.start(
      port: 0,
      address: InternetAddress.loopbackIPv4,
      readHistory: repository.load,
      generateLicense: generate,
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await access.stop();
    await directory.delete(recursive: true);
  });

  test(
    'Serves the dashboard without exposing credentials or signing secrets',
    () async {
      final result = await request('/', authenticated: false);
      expect(result.status, 200);
      expect(result.body, contains('Histórico'));
      expect(result.body, contains('<h1>Gerador de Licenças</h1>'));
      expect(result.body, contains('Expiradas'));
      expect(result.body, isNot(contains(secret)));
      expect(result.body, isNot(contains(defaultLicenseSecret)));
      expect(result.body, isNot(contains(info.password)));
      expect(result.body, isNot(contains('__NONCE__')));
      expect(
        result.headers.value('Content-Security-Policy'),
        contains("script-src 'nonce-"),
      );
      expect(result.headers.value('Cache-Control'), 'no-store');
    },
  );

  test('Requires authentication for reading and generating keys', () async {
    expect((await request('/api/history', authenticated: false)).status, 401);
    expect(
      (await request(
        '/api/licenses',
        method: 'POST',
        body: input('denied'),
        authenticated: false,
      )).status,
      401,
    );
    expect(
      (await request(
        '/api/history',
        headers: {'Authorization': 'Bearer wrong'},
      )).status,
      401,
    );
    expect(await repository.load(), isEmpty);
  });

  test(
    'Generates a compatible signed key and persists its date and amount',
    () async {
      final result = await request(
        '/api/licenses',
        method: 'POST',
        body: input('empresa_rede'),
      );
      expect(result.status, 201);
      final entry = jsonDecode(result.body) as Map<String, dynamic>;
      expect(entry['amountCents'], 123456);
      expect(entry['createdAt'], '2026-10-25T16:39:18.000Z');
      final parts = utf8
          .decode(base64Url.decode(entry['code'] as String))
          .split('|');
      expect(
        parts.take(3).join('|'),
        'empresa_rede|aabbccdd|2027-03-25T16:39:18.000Z',
      );
      expect(
        parts.last,
        Hmac(
          sha256,
          utf8.encode(secret),
        ).convert(utf8.encode(parts.take(3).join('|'))).toString(),
      );
      final history =
          jsonDecode((await request('/api/history')).body)
              as Map<String, dynamic>;
      expect((history['entries'] as List<dynamic>).single, entry);
      final reopened = LicenseHistoryRepository(
        HistoryStorage(directory: () async => directory),
      );
      expect((await reopened.load()).single.toJson(), entry);
    },
  );

  test('Keeps all simultaneous browser and desktop generations', () async {
    final results = await Future.wait([
      for (var i = 0; i < 10; i++)
        request('/api/licenses', method: 'POST', body: input('browser_$i')),
    ]);
    expect(results.every((result) => result.status == 201), isTrue);
    await repository.add(
      generateLicenseRecord(
        customerId: 'desktop',
        hardwareId: 'AABB',
        months: 1,
        secret: secret,
        now: DateTime.now(),
      ),
    );
    final entries = await repository.load();
    expect(entries, hasLength(11));
    expect(entries.map((entry) => entry.customerId).toSet(), hasLength(11));
  });

  test(
    'Rejects invalid input and oversized requests without changing history',
    () async {
      expect(
        (await request(
          '/api/licenses',
          method: 'POST',
          body: {...input('bad'), 'months': 0},
        )).status,
        400,
      );
      expect(
        (await request(
          '/api/licenses',
          method: 'POST',
          body: {...input('bad'), 'amount': '-1'},
        )).status,
        400,
      );
      expect(
        (await request(
          '/api/licenses',
          method: 'POST',
          body: {'customerId': 'bad'},
        )).status,
        400,
      );
      expect(
        (await request(
          '/api/licenses',
          method: 'POST',
          body: {'customerId': 'x' * 9000},
        )).status,
        413,
      );
      expect(await repository.load(), isEmpty);
    },
  );

  test('Blocks cross-origin access and unexpected host names', () async {
    expect(
      (await request(
        '/api/history',
        headers: {'Origin': 'http://other.invalid'},
      )).status,
      403,
    );
    expect(
      (await request(
        '/api/history',
        headers: {'Host': 'other.invalid:${info.port}'},
      )).status,
      403,
    );
    expect(
      (await request(
        '/api/history',
        headers: {'Origin': 'http://127.0.0.1:${info.port}'},
      )).status,
      200,
    );
  });

  test(
    'Keeps the configured access password after restarting the server',
    () async {
      final previousPassword = info.password;
      expect(previousPassword, '88336092');
      await access.stop();
      info = await access.start(
        port: 0,
        address: InternetAddress.loopbackIPv4,
        readHistory: repository.load,
        generateLicense: generate,
      );
      expect(info.password, previousPassword);
      expect(
        (await request(
          '/api/history',
          headers: {'Authorization': 'Bearer $previousPassword'},
        )).status,
        200,
      );
      expect((await request('/api/history')).status, 200);
    },
  );

  test(
    'A failed write preserves history and does not block later generations',
    () async {
      await request('/api/licenses', method: 'POST', body: input('existing'));
      await Directory('${directory.path}/license_history.json.tmp').create();
      expect(
        (await request(
          '/api/licenses',
          method: 'POST',
          body: input('failed'),
        )).status,
        500,
      );
      expect((await repository.load()).single.customerId, 'existing');
      await Directory('${directory.path}/license_history.json.tmp').delete();
      expect(
        (await request(
          '/api/licenses',
          method: 'POST',
          body: input('recovered'),
        )).status,
        201,
      );
      expect(await repository.load(), hasLength(2));
    },
  );
}
