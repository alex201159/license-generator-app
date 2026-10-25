import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'currency.dart';
import 'license_entry.dart';

const defaultLicenseSecret = 'LC_CARGA_LICENSE_SECRET';

SavedLicenseEntry generateLicenseRecord({
  required String customerId,
  required String hardwareId,
  required int months,
  required String secret,
  required DateTime now,
  int? amountCents,
}) {
  customerId = customerId.trim();
  hardwareId = hardwareId.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toLowerCase();
  if (customerId.isEmpty ||
      hardwareId.isEmpty ||
      months <= 0 ||
      secret.isEmpty ||
      (amountCents != null && amountCents < 0)) {
    throw const FormatException('Informe todos os campos corretamente.');
  }
  now = now.toUtc();
  late DateTime expiry;
  try {
    expiry = DateTime.utc(
      now.year,
      now.month + months,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
  } on ArgumentError {
    throw const FormatException('Informe uma validade em meses válida.');
  }
  final payload = '$customerId|$hardwareId|${expiry.toIso8601String()}';
  final signature = Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode(payload));
  return SavedLicenseEntry(
    customerId: customerId,
    validity: expiry.toIso8601String(),
    code: base64Url.encode(utf8.encode('$payload|$signature')),
    createdAt: now,
    amountCents: amountCents,
  );
}

SavedLicenseEntry generateLicenseFromRequest(
  Map<String, dynamic> input, {
  required String secret,
  required DateTime now,
}) {
  final customer = input['customerId'];
  final hardware = input['hardwareId'];
  final months = input['months'];
  final amount = input['amount'];
  if (customer is! String ||
      hardware is! String ||
      months is! int ||
      (amount != null && amount is! String)) {
    throw const FormatException(
      'Informe cliente, código da máquina e validade em meses.',
    );
  }
  final amountText = (amount as String? ?? '').trim();
  final cents = amountText.isEmpty ? null : parseAmountCents(amountText);
  if (amountText.isNotEmpty && cents == null) {
    throw const FormatException(
      'Informe um valor válido em reais (ex.: 150,00).',
    );
  }
  return generateLicenseRecord(
    customerId: customer,
    hardwareId: hardware,
    months: months,
    secret: secret,
    now: now,
    amountCents: cents,
  );
}
