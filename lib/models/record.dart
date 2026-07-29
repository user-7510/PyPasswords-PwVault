import 'dart:math';

class PasswordRecord {
  String id;
  String accountType;
  String accountName;
  String password;
  String linkedAccount;
  String name;
  List<String> notes;

  PasswordRecord({
    required this.id,
    this.accountType = '',
    this.accountName = '',
    this.password = '',
    this.linkedAccount = '',
    this.name = '',
    List<String>? notes,
  }) : notes = notes ?? [];

  factory PasswordRecord.newRecord() {
    return PasswordRecord(id: generateId());
  }

  static String generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  factory PasswordRecord.fromJson(Map<String, dynamic> json) {
    return PasswordRecord(
      id: json['id']?.toString() ?? generateId(),
      accountType: json['accountType']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      linkedAccount: json['linkedAccount']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      notes: (json['notes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountType': accountType,
      'accountName': accountName,
      'password': password,
      'linkedAccount': linkedAccount,
      'name': name,
      'notes': notes,
    };
  }
}
