class SavedLicenseEntry {
  const SavedLicenseEntry({
    required this.customerId,
    required this.validity,
    required this.code,
    this.createdAt,
    this.amountCents,
  });

  final String customerId;
  final String validity;
  final String code;
  final DateTime? createdAt;
  final int? amountCents;

  factory SavedLicenseEntry.fromJson(Map<String, dynamic> json) {
    return SavedLicenseEntry(
      customerId: json['customerId'] as String,
      validity: json['validity'] as String,
      code: json['code'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      amountCents: json['amountCents'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'validity': validity,
    'code': code,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (amountCents != null) 'amountCents': amountCents,
  };
}
