int? parseAmountCents(String input) {
  var value = input.trim().replaceFirst(RegExp(r'^R\$\s*'), '');
  if (RegExp(r'^\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$').hasMatch(value)) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d+(?:[,.]\d{1,2})?$').hasMatch(value)) {
    value = value.replaceAll(',', '.');
  } else {
    return null;
  }

  final parts = value.split('.');
  final whole = int.tryParse(parts.first);
  // Keep monetary values exact on both native platforms and the web.
  if (whole == null || whole > 90071992547409) return null;
  final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final cents = whole * 100 + fraction;
  return cents <= 9007199254740991 ? cents : null;
}

String formatAmountCents(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return 'R\$ $whole,$fraction';
}
