import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'history_storage.dart';
import 'currency.dart';
import 'license_entry.dart';
import 'license_history_repository.dart';
import 'license_service.dart';
import 'network_settings_panel.dart';
import 'network_access.dart';
import 'network_session_controller.dart';

export 'license_entry.dart';

void main() {
  FlutterError.onError = (details) {
    if (_isHardwareKeyboardAssertion(details.exception)) {
      return;
    }
    FlutterError.presentError(details);
  };
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const LicenseGeneratorApp());
    },
    (error, stack) {
      if (_isHardwareKeyboardAssertion(error)) {
        return;
      }
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}

bool _isHardwareKeyboardAssertion(Object? error) {
  final message = error?.toString() ?? '';
  return message.contains('HardwareKeyboard') &&
      message.contains('_pressedKeys.containsKey(event.physicalKey)') &&
      message.contains('KeyUpEvent');
}

class LicenseGeneratorApp extends StatelessWidget {
  const LicenseGeneratorApp({
    super.key,
    this.historyStorage,
    this.now,
    this.networkAccess,
  });

  final HistoryStorage? historyStorage;
  final DateTime Function()? now;
  final NetworkAccess? networkAccess;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerador de Licenças',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFF6C63FF),
              secondary: const Color(0xFF4ECDC4),
              tertiary: const Color(0xFFFF6B9D),
              surface: const Color(0xFFFAFAFA),
              surfaceContainerHighest: const Color(0xFFF0F0F5),
            ),
        fontFamily: 'Inter',
      ),
      home: LicenseGeneratorPage(
        historyStorage: historyStorage,
        now: now,
        networkAccess: networkAccess,
      ),
    );
  }
}

class LicenseGeneratorPage extends StatefulWidget {
  const LicenseGeneratorPage({
    super.key,
    this.historyStorage,
    this.now,
    this.networkAccess,
  });

  final HistoryStorage? historyStorage;
  final DateTime Function()? now;
  final NetworkAccess? networkAccess;

  @override
  State<LicenseGeneratorPage> createState() => _LicenseGeneratorPageState();
}

class _LicenseGeneratorPageState extends State<LicenseGeneratorPage>
    with WidgetsBindingObserver {
  final _customerController = TextEditingController();
  final _hardwareController = TextEditingController();
  final _monthsController = TextEditingController(text: '1');
  final _amountController = TextEditingController();
  final _secretController = TextEditingController(text: defaultLicenseSecret);
  final List<SavedLicenseEntry> _savedLicenses = [];
  String? _licenseCode;
  String? _validity;
  String? _error;
  bool _saveHistory = true;
  late final LicenseHistoryRepository _historyRepository;
  late final NetworkSessionController _networkSession;
  bool _isLoadingHistory = true;
  bool _isSavingHistory = false;
  String? _historyError;
  Timer? _expiryTimer;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _historyRepository = LicenseHistoryRepository(
      widget.historyStorage ?? HistoryStorage(),
    );
    _networkSession = NetworkSessionController(
      access: widget.networkAccess,
      readHistory: _historyRepository.load,
      generateLicense: _generateNetworkLicense,
    );
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    try {
      final entries = await _historyRepository.load();
      if (!mounted) return;
      setState(() {
        _savedLicenses
          ..clear()
          ..addAll(entries);
        _isLoadingHistory = false;
      });
      _scheduleExpiryRefresh();
      unawaited(_networkSession.start());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError =
            'Não foi possível carregar o histórico salvo. '
            'Tente novamente antes de salvar novas ativações.';
      });
    }
  }

  Future<void> _generateLicense() async {
    if (_isLoadingHistory || _isSavingHistory) return;
    final saveHistory = _saveHistory;
    if (saveHistory && _historyError != null) return;
    final customerId = _customerController.text.trim();
    final hardwareId = _hardwareController.text
        .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
        .toLowerCase();
    final months = int.tryParse(_monthsController.text.trim());
    final secret = _secretController.text.trim();
    if (customerId.isEmpty ||
        months == null ||
        months <= 0 ||
        secret.isEmpty ||
        hardwareId.isEmpty) {
      setState(() {
        _error = 'Informe todos os campos corretamente.';
        _licenseCode = null;
        _validity = null;
      });
      return;
    }
    final amountInput = _amountController.text.trim();
    final amountCents = amountInput.isEmpty
        ? null
        : parseAmountCents(amountInput);
    if (amountInput.isNotEmpty && amountCents == null) {
      setState(() {
        _error = 'Informe um valor válido em reais (ex.: 150,00).';
        _licenseCode = null;
        _validity = null;
      });
      return;
    }
    late SavedLicenseEntry entry;
    try {
      entry = generateLicenseRecord(
        customerId: customerId,
        hardwareId: hardwareId,
        months: months,
        secret: secret,
        now: _now(),
        amountCents: amountCents,
      );
    } on FormatException catch (error) {
      setState(() {
        _error = error.message;
        _licenseCode = null;
        _validity = null;
      });
      return;
    }
    if (saveHistory) {
      setState(() {
        _isSavingHistory = true;
        _error = null;
      });
      try {
        await _saveRecord(entry);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isSavingHistory = false;
          _error =
              'Não foi possível salvar a licença no histórico. '
              'Tente gerar novamente.';
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _licenseCode = entry.code;
      _validity = entry.validity;
      _error = null;
      _isSavingHistory = false;
    });
    _scheduleExpiryRefresh();
  }

  Future<void> _saveRecord(SavedLicenseEntry entry) async {
    final entries = await _historyRepository.add(entry);
    if (!mounted) return;
    setState(() {
      _savedLicenses
        ..clear()
        ..addAll(entries);
    });
    _scheduleExpiryRefresh();
  }

  Future<SavedLicenseEntry> _generateNetworkLicense(
    Map<String, dynamic> input,
  ) async {
    final entry = generateLicenseFromRequest(
      input,
      secret: _secretController.text.trim(),
      now: _now(),
    );
    await _saveRecord(entry);
    return entry;
  }

  bool _isExpired(SavedLicenseEntry entry, DateTime now) {
    final validity = _parseValidity(entry.validity);
    return validity != null && !validity.isAfter(now);
  }

  void _scheduleExpiryRefresh() {
    _expiryTimer?.cancel();
    final now = _now();
    final upcoming =
        _savedLicenses
            .map((entry) => _parseValidity(entry.validity))
            .whereType<DateTime>()
            .where((date) => date.isAfter(now))
            .toList()
          ..sort();
    if (upcoming.isEmpty) return;
    final delay = upcoming.first.difference(now);
    _expiryTimer = Timer(
      delay > const Duration(days: 1) ? const Duration(days: 1) : delay,
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleExpiryRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _scheduleExpiryRefresh();
    }
  }

  void _copyLicense() {
    if (_licenseCode == null) return;
    Clipboard.setData(ClipboardData(text: _licenseCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Código copiado com sucesso!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  DateTime? _parseValidity(String value) {
    return DateTime.tryParse(value)?.toLocal();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatGenerationMonth(DateTime? month) {
    if (month == null) return 'Sem data de geração';
    const names = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${names[month.month - 1]} de ${month.year}';
  }

  int? _daysUntil(DateTime? date) {
    if (date == null) return null;
    return date.difference(_now()).inDays;
  }

  String _expiryDetail(int? days) {
    if (days == null) return 'Data inválida';
    if (days == 0) return 'Expira hoje';
    if (days == 1) return 'Expira em 1 dia';
    if (days > 1) return 'Expira em $days dias';
    final expiredDays = days.abs();
    return expiredDays == 1
        ? 'Expirou há 1 dia'
        : 'Expirou há $expiredDays dias';
  }

  Widget _buildStatCard({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                label == 'Total'
                    ? Icons.grid_view_rounded
                    : label == 'Ativas'
                    ? Icons.check_circle_outline
                    : label == 'Expiradas'
                    ? Icons.cancel_outlined
                    : Icons.help_outline,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateTab(
    ColorScheme colorScheme,
    String? license,
    String validityDisplay,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.95),
                colorScheme.secondary.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Gerar nova licença',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crie códigos autênticos e seguros',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.15),
                          colorScheme.secondary.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.edit_document,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dados da Ativação',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Preencha as informações abaixo',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _customerController,
                decoration: InputDecoration(
                  labelText: 'Cliente (ID único)',
                  hintText: 'Ex: empresa_123',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(Icons.business, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _hardwareController,
                decoration: InputDecoration(
                  labelText: 'Código da máquina',
                  hintText: 'Cole o código do sistema',
                  helperText: 'Código exibido no sistema a ativar',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(Icons.computer, color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _monthsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Validade (meses)',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.schedule,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _secretController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Chave secreta',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.vpn_key,
                          color: colorScheme.primary,
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Copiar chave',
                          icon: Icon(Icons.copy, color: colorScheme.primary),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _secretController.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 12),
                                    Text('Chave copiada!'),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('license-amount'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Valor (R\$)',
                  hintText: 'Ex.: 150,00',
                  helperText: 'Opcional',
                  prefixText: 'R\$ ',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _saveHistory
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history,
                        color: _saveHistory
                            ? colorScheme.primary
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salvar no histórico',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Guarda informações da licença',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _saveHistory,
                      onChanged: _isLoadingHistory || _isSavingHistory
                          ? null
                          : (value) {
                              setState(() {
                                _saveHistory = value;
                              });
                            },
                      activeTrackColor: colorScheme.primary.withValues(
                        alpha: 0.5,
                      ),
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed:
                      _isLoadingHistory ||
                          _isSavingHistory ||
                          (_saveHistory && _historyError != null)
                      ? null
                      : _generateLicense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        _isLoadingHistory
                            ? 'Carregando histórico...'
                            : _isSavingHistory
                            ? 'Salvando...'
                            : 'Gerar Licença',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (license != null) ...[
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.green.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.verified,
                        color: Colors.green.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ Licença Gerada',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade900,
                                ),
                          ),
                          Text(
                            'Código pronto para uso',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _copyLicense,
                        icon: Icon(
                          Icons.copy_all,
                          color: Colors.green.shade700,
                        ),
                        tooltip: 'Copiar código',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: SelectableText(
                    license,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Validade: $validityDisplay',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivationCard(
    SavedLicenseEntry entry,
    ColorScheme colorScheme,
  ) {
    final validity = _parseValidity(entry.validity);
    final days = _daysUntil(validity);
    final expired = _isExpired(entry, _now());
    final status = validity == null
        ? 'Indefinida'
        : (expired ? 'Expirada' : 'Ativa');
    final detail = expired && days == 0 ? 'Expirou hoje' : _expiryDetail(days);
    final statusColor = days == null
        ? colorScheme.tertiary
        : (expired ? Colors.red.shade600 : Colors.green.shade600);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withValues(alpha: 0.2),
                      statusColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  validity != null && !expired
                      ? Icons.verified_user
                      : Icons.lock_clock,
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.customerId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (entry.createdAt != null) ...[
                      Text(
                        'Gerada em: ${_formatDate(entry.createdAt!.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Validade: ${_formatDate(validity)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Valor: ${entry.amountCents == null ? 'Não informado' : formatAmountCents(entry.amountCents!)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.timelapse, size: 20, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: SelectableText(
              entry.code,
              key: PageStorageKey<String>('activation-code-${entry.code}'),
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationTab(
    ColorScheme colorScheme, {
    bool expiredOnly = false,
  }) {
    final now = _now();
    final total = _savedLicenses.length;
    final active = _savedLicenses.where((entry) {
      return _parseValidity(entry.validity) != null && !_isExpired(entry, now);
    }).length;
    final expired = _savedLicenses.where((entry) {
      return _isExpired(entry, now);
    }).length;
    final unknown = total - active - expired;
    final entries = _savedLicenses
        .where((entry) => _isExpired(entry, now) == expiredOnly)
        .toList();
    final groups = <DateTime?, List<SavedLicenseEntry>>{};
    for (final entry in entries) {
      final createdAt = entry.createdAt?.toLocal();
      final month = createdAt == null
          ? null
          : DateTime(createdAt.year, createdAt.month);
      groups.putIfAbsent(month, () => []).add(entry);
    }
    final months = groups.keys.toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });

    return ListView(
      key: PageStorageKey<String>(
        expiredOnly ? 'expired-licenses' : 'current-licenses',
      ),
      padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.95),
                colorScheme.tertiary.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.dashboard_customize,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expiredOnly
                              ? 'Chaves Expiradas'
                              : 'Histórico de Ativações',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          expiredOnly
                              ? 'Licenças cuja validade terminou'
                              : 'Acompanhe as licenças ativas por mês de geração',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (expiredOnly)
                Row(
                  children: [
                    _buildStatCard(
                      label: 'Expiradas',
                      value: expired,
                      color: Colors.redAccent.shade200,
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    _buildStatCard(
                      label: 'Total',
                      value: total,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      label: 'Ativas',
                      value: active,
                      color: Colors.greenAccent.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard(
                      label: 'Expiradas',
                      value: expired,
                      color: Colors.redAccent.shade200,
                    ),
                    const SizedBox(width: 12),
                    if (unknown > 0)
                      _buildStatCard(
                        label: 'Indefinidas',
                        value: unknown,
                        color: Colors.orangeAccent.shade200,
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoadingHistory)
          const Center(child: CircularProgressIndicator())
        else if (entries.isEmpty && _historyError == null)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.15),
                        colorScheme.secondary.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: colorScheme.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  expiredOnly
                      ? 'Nenhuma chave expirada'
                      : 'Nenhuma ativação registrada',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  expiredOnly
                      ? 'As chaves aparecerão aqui quando a validade terminar'
                      : 'Gere sua primeira licença para começar',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          for (final month in months)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: ExpansionTile(
                key: PageStorageKey<String>(
                  'activation-month-${month?.toIso8601String() ?? 'undated'}',
                ),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.folder_rounded, color: colorScheme.primary),
                ),
                title: Text(
                  _formatGenerationMonth(month),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                subtitle: Text(
                  '${groups[month]!.length} '
                  '${groups[month]!.length == 1 ? 'ativação' : 'ativações'}',
                ),
                children: [
                  for (final entry in groups[month]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildActivationCard(entry, colorScheme),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkSession.dispose();
    _expiryTimer?.cancel();
    _customerController.dispose();
    _hardwareController.dispose();
    _monthsController.dispose();
    _amountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final license = _licenseCode;
    final validityDisplay = _validity ?? '—';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFF5F7FA), const Color(0xFFE8EBF0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: DefaultTabController(
            length: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                'Gerador de Licenças',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sistema de Gerenciamento de Licenças',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildBadge('🔒 Seguro'),
                            _buildBadge('⚡ Rápido'),
                            _buildBadge('✨ Premium'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.15),
                            colorScheme.secondary.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: Colors.grey.shade600,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.all(6),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.add_circle_outline),
                          text: 'Gerar',
                        ),
                        Tab(icon: Icon(Icons.history), text: 'Histórico'),
                        Tab(icon: Icon(Icons.lock_clock), text: 'Expiradas'),
                        Tab(icon: Icon(Icons.lan_outlined), text: 'Rede'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_historyError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(_historyError!)),
                          TextButton(
                            onPressed: _loadHistory,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGenerateTab(
                          colorScheme,
                          license,
                          validityDisplay,
                        ),
                        _buildActivationTab(colorScheme),
                        _buildActivationTab(colorScheme, expiredOnly: true),
                        NetworkSettingsPanel(
                          canStart: !_isLoadingHistory && _historyError == null,
                          session: _networkSession,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
