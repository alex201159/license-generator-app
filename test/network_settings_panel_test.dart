import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_generator_app/network_access.dart';
import 'package:license_generator_app/network_settings_panel.dart';
import 'package:license_generator_app/network_session_controller.dart';

import 'network_test_fakes.dart';

void main() {
  testWidgets(
    'Keeps network access active while switching tabs and allows stopping it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final access = FakeNetworkAccess();
      final session = NetworkSessionController(
        access: access,
        readHistory: () async => [],
        generateLicense: (_) async => throw UnimplementedError(),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Scaffold(
              body: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Início'),
                      Tab(text: 'Formulário'),
                      Tab(text: 'Histórico'),
                      Tab(text: 'Rede'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        const Center(child: Text('Tela inicial')),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                        NetworkSettingsPanel(session: session, canStart: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rede'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ativar acesso pela rede'));
      await tester.pumpAndSettle();
      expect(access.running, isTrue);
      expect(find.text('http://192.168.1.10:8787'), findsOneWidget);
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).last,
      );
      expect(passwordField.controller!.text, defaultNetworkPassword);
      expect(passwordField.obscureText, isTrue);

      await tester.tap(find.text('Início'));
      await tester.pumpAndSettle();
      expect(access.running, isTrue);
      await tester.tap(find.text('Rede'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desativar acesso pela rede'));
      await tester.pumpAndSettle();
      expect(access.running, isFalse);
      expect(find.text('http://192.168.1.10:8787'), findsNothing);
      expect(find.text('Ativar acesso pela rede'), findsOneWidget);
    },
  );
}
