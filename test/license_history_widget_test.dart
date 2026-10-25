import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_generator_app/history_storage.dart';
import 'package:license_generator_app/main.dart';

import 'network_test_fakes.dart';

class MemoryHistoryStorage extends HistoryStorage {
  String? contents;
  bool failWrites = false;
  Completer<String?>? pendingRead;

  @override
  Future<String?> read() async => pendingRead?.future ?? contents;

  @override
  Future<void> write(String contents) async {
    if (failWrites) throw StateError('Storage unavailable');
    this.contents = contents;
  }
}

const previousEntry = SavedLicenseEntry(
  customerId: 'cliente_anterior',
  validity: '2030-01-01T00:00:00.000Z',
  code: 'codigo_anterior',
);

Future<FakeNetworkAccess> openApp(
  WidgetTester tester,
  MemoryHistoryStorage storage, {
  FakeNetworkAccess? networkAccess,
}) async {
  final access = networkAccess ?? FakeNetworkAccess();
  await tester.pumpWidget(
    LicenseGeneratorApp(historyStorage: storage, networkAccess: access),
  );
  await tester.pumpAndSettle();
  return access;
}

Future<void> generateLicense(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'empresa_123');
  await tester.enterText(find.byType(TextField).at(1), 'AA-BB-CC-DD');
  await tester.ensureVisible(
    find.widgetWithText(ElevatedButton, 'Gerar Licença'),
  );
  await tester.tap(find.widgetWithText(ElevatedButton, 'Gerar Licença'));
  await tester.pumpAndSettle();
}

Future<void> toggleHistoryFolder(WidgetTester tester, String month) async {
  await tester.tap(find.text(month));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Restores generated activations after reopening the app', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage();
    await openApp(tester, storage);
    await tester.enterText(
      find.byKey(const ValueKey('license-amount')),
      '1.234,56',
    );
    await generateLicense(tester);
    final saved = jsonDecode(storage.contents!) as List<dynamic>;
    expect(saved.single['customerId'], 'empresa_123');
    expect(saved.single['amountCents'], 123456);
    final savedCode = saved.single['code'] as String;
    final generatedAt = DateTime.parse(saved.single['createdAt'] as String);
    expect(generatedAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));

    await tester.pumpWidget(const SizedBox.shrink());
    await openApp(tester, storage);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('Sem data de geração'), findsNothing);
    expect(find.textContaining('Gerada em:'), findsOneWidget);
    expect(find.text('Valor: R\$ 1.234,56'), findsOneWidget);
    expect(find.text('empresa_123'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == savedCode,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Gerar'));
    await tester.pumpAndSettle();
    await generateLicense(tester);
    expect((jsonDecode(storage.contents!) as List<dynamic>).length, 2);
    expect(
      (jsonDecode(storage.contents!) as List<dynamic>).last['amountCents'],
      123456,
    );
  });

  testWidgets('Keeps existing history when saving is switched off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage()
      ..contents = jsonEncode([previousEntry]);
    final original = storage.contents;
    await openApp(tester, storage);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await generateLicense(tester);
    expect(storage.contents, original);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await toggleHistoryFolder(tester, 'Sem data de geração');
    expect(find.text('cliente_anterior'), findsOneWidget);
    expect(find.text('Valor: Não informado'), findsOneWidget);
    expect(find.text('empresa_123'), findsNothing);
  });

  testWidgets('Protects unreadable history and allows retrying the load', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage()..contents = 'invalid json';
    final access = await openApp(tester, storage);
    expect(access.running, isFalse);
    expect(
      find.textContaining('Não foi possível carregar o histórico'),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(storage.contents, 'invalid json');
    storage.contents = jsonEncode([previousEntry]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível carregar o histórico'),
      findsNothing,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(access.running, isTrue);
  });

  testWidgets('Waits for existing history before enabling generation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage()..pendingRead = Completer<String?>();
    final access = FakeNetworkAccess();
    await tester.pumpWidget(
      LicenseGeneratorApp(historyStorage: storage, networkAccess: access),
    );
    expect(access.running, isFalse);
    expect(find.text('Carregando histórico...'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    storage.pendingRead!.complete(jsonEncode([previousEntry]));
    await tester.pumpAndSettle();
    expect(access.running, isTrue);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await toggleHistoryFolder(tester, 'Sem data de geração');
    expect(find.text('cliente_anterior'), findsOneWidget);
  });

  testWidgets('Reports a write failure without losing previous activations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage()
      ..contents = jsonEncode([previousEntry])
      ..failWrites = true;
    final original = storage.contents;
    await openApp(tester, storage);
    await generateLicense(tester);
    expect(
      find.textContaining('Não foi possível salvar a licença'),
      findsOneWidget,
    );
    expect(storage.contents, original);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await toggleHistoryFolder(tester, 'Sem data de geração');
    expect(find.text('cliente_anterior'), findsOneWidget);
    expect(find.text('empresa_123'), findsNothing);
  });

  testWidgets('Opens and closes monthly folders with the newest month first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage()
      ..contents = jsonEncode([
        SavedLicenseEntry(
          customerId: 'cliente_setembro',
          validity: '2030-01-01T00:00:00.000Z',
          code: 'codigo_setembro',
          createdAt: DateTime.utc(2026, 9, 15, 12),
        ),
        previousEntry,
        SavedLicenseEntry(
          customerId: 'cliente_outubro',
          validity: '2030-01-01T00:00:00.000Z',
          code: 'codigo_outubro',
          createdAt: DateTime.utc(2026, 10, 15, 12),
        ),
      ]);
    await openApp(tester, storage);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Setembro de 2026'), findsOneWidget);
    expect(find.text('Sem data de geração'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Outubro de 2026')).dy,
      lessThan(tester.getTopLeft(find.text('Setembro de 2026')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Setembro de 2026')).dy,
      lessThan(tester.getTopLeft(find.text('Sem data de geração')).dy),
    );
    expect(find.text('cliente_outubro'), findsNothing);
    expect(find.text('cliente_setembro'), findsNothing);
    expect(find.text('cliente_anterior'), findsNothing);
    await toggleHistoryFolder(tester, 'Outubro de 2026');
    expect(find.text('cliente_outubro'), findsOneWidget);
    expect(find.text('cliente_setembro'), findsNothing);
    await toggleHistoryFolder(tester, 'Outubro de 2026');
    expect(find.text('cliente_outubro'), findsNothing);
    await toggleHistoryFolder(tester, 'Setembro de 2026');
    expect(find.text('cliente_setembro'), findsOneWidget);
    expect(find.text('cliente_outubro'), findsNothing);
    await toggleHistoryFolder(tester, 'Sem data de geração');
    expect(find.text('cliente_anterior'), findsOneWidget);
    expect(find.text('Janeiro de 2030'), findsNothing);
  });

  testWidgets(
    'Moves expired keys to their own tab at the exact expiration time',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var now = DateTime.utc(2026, 10, 25, 16);
      final generatedAt = now.subtract(const Duration(days: 1));
      final storage = MemoryHistoryStorage()
        ..contents = jsonEncode([
          SavedLicenseEntry(
            customerId: 'cliente_ativo',
            validity: now.add(const Duration(days: 1)).toIso8601String(),
            code: 'ativa',
            createdAt: generatedAt,
          ),
          SavedLicenseEntry(
            customerId: 'cliente_expirado',
            validity: now.subtract(const Duration(hours: 1)).toIso8601String(),
            code: 'expirada',
            createdAt: generatedAt,
            amountCents: 15000,
          ),
          SavedLicenseEntry(
            customerId: 'cliente_expirando',
            validity: now.add(const Duration(seconds: 10)).toIso8601String(),
            code: 'expirando',
            createdAt: generatedAt,
          ),
        ]);
      await tester.pumpWidget(
        LicenseGeneratorApp(
          historyStorage: storage,
          now: () => now,
          networkAccess: FakeNetworkAccess(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Histórico'));
      await tester.pumpAndSettle();
      await toggleHistoryFolder(tester, 'Outubro de 2026');
      expect(find.text('cliente_ativo'), findsOneWidget);
      expect(find.text('cliente_expirando'), findsOneWidget);
      expect(find.text('cliente_expirado'), findsNothing);

      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('cliente_ativo'), findsOneWidget);
      expect(find.text('cliente_expirando'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Expiradas'));
      await tester.pumpAndSettle();
      await toggleHistoryFolder(tester, 'Outubro de 2026');
      expect(find.text('cliente_expirado'), findsOneWidget);
      expect(find.text('cliente_expirando'), findsOneWidget);
      expect(find.text('cliente_ativo'), findsNothing);
      expect(find.text('Expirou hoje'), findsNWidgets(2));
      expect(find.text('Valor: R\$ 150,00'), findsOneWidget);
      expect((jsonDecode(storage.contents!) as List<dynamic>).length, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        LicenseGeneratorApp(
          historyStorage: storage,
          now: () => now,
          networkAccess: FakeNetworkAccess(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Expiradas'));
      await tester.pumpAndSettle();
      await toggleHistoryFolder(tester, 'Outubro de 2026');
      expect(find.text('cliente_expirado'), findsOneWidget);
      expect(find.text('cliente_expirando'), findsOneWidget);
      expect(find.text('cliente_ativo'), findsNothing);
      expect(find.text('Valor: R\$ 150,00'), findsOneWidget);
    },
  );

  testWidgets('Rejects invalid amounts and allows a zero-value activation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryHistoryStorage();
    await openApp(tester, storage);
    await tester.enterText(
      find.byKey(const ValueKey('license-amount')),
      '-150,00',
    );
    await generateLicense(tester);
    expect(
      find.text('Informe um valor válido em reais (ex.: 150,00).'),
      findsOneWidget,
    );
    expect(storage.contents, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('license-amount')),
      '0,00',
    );
    await generateLicense(tester);
    expect(
      (jsonDecode(storage.contents!) as List<dynamic>).single['amountCents'],
      0,
    );
  });
  testWidgets(
    'Starts the server before visiting Rede and keeps the fixed password after reopening',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = MemoryHistoryStorage();
      final access = await openApp(tester, storage);
      expect(find.text('Gerador de Licenças'), findsOneWidget);
      expect(access.running, isTrue);
      expect(access.startCount, 1);
      expect(access.info!.port, 8787);
      expect(access.info!.password, '88336092');

      await tester.tap(find.widgetWithText(Tab, 'Rede'));
      await tester.pumpAndSettle();
      expect(find.text('Desativar acesso pela rede'), findsOneWidget);
      expect(access.startCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(access.running, isFalse);
      await openApp(tester, storage, networkAccess: access);
      expect(access.running, isTrue);
      expect(access.startCount, 2);
      expect(access.info!.password, '88336092');
    },
  );
}
