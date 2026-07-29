import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/record.dart';
import 'crypto_service.dart';

const String symbolChars = '!@#\$%^&*()-_=+[]{}';

final RegExp profileNamePattern = RegExp(r'^[\w\-\u4e00-\u9fff]+$');

const List<String> commonWeakPasswords = [
  'password', '123456', '12345678', 'qwerty', '111111',
  '123456789', 'abc123', 'password1', 'iloveyou', 'admin',
  'letmein', 'welcome', 'monkey', 'dragon', 'master',
  '000000', '1234567', 'sunshine', 'princess', 'football',
];

class VaultSession {
  final String profile;
  final Uint8List salt;
  final String masterPassword;
  List<PasswordRecord> records;
  VaultSession({
    required this.profile,
    required this.salt,
    required this.masterPassword,
    required this.records,
  });
}

class VaultService {
  static Future<Directory> vaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/pwvault');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> vaultFile(String profile) async {
    final dir = await vaultDir();
    return File('${dir.path}/$profile.pwv2');
  }

  static bool isValidProfileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    return profileNamePattern.hasMatch(trimmed);
  }

  static Future<List<String>> listProfiles() async {
    final dir = await vaultDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pwv2'));
    final names = files.map((f) {
      final base = f.uri.pathSegments.last;
      return base.substring(0, base.length - '.pwv2'.length);
    }).toList();
    names.sort();
    return names;
  }

  static Future<bool> profileExists(String profile) async {
    final file = await vaultFile(profile);
    return file.exists();
  }

  /// 建立新設定檔（或重設既有設定檔，清空所有紀錄）
  static Future<void> setupMasterPassword(String profile, String masterPassword) async {
    final file = await vaultFile(profile);
    final salt = CryptoService.randomBytes(CryptoService.saltSize);
    final emptyPayload = utf8.encode(jsonEncode({'records': []}));
    final bytes = await CryptoService.encryptToFile(
      masterPassword: masterPassword,
      salt: salt,
      plaintext: emptyPayload,
    );
    await _atomicWrite(file, bytes);
  }

  /// 以主碼解鎖設定檔，失敗回傳 null
  static Future<VaultSession?> unlock(String profile, String masterPassword) async {
    final file = await vaultFile(profile);
    if (!await file.exists()) return null;
    final fileBytes = await file.readAsBytes();
    final result = await CryptoService.decryptFile(
      masterPassword: masterPassword,
      fileBytes: fileBytes,
    );
    if (result == null) return null;
    final decoded = jsonDecode(utf8.decode(result.plaintext));
    final recordsJson = (decoded is Map && decoded['records'] is List) ? decoded['records'] as List : [];
    final records = recordsJson
        .whereType<Map>()
        .map((e) => PasswordRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final session = VaultSession(
      profile: profile,
      salt: result.salt,
      masterPassword: masterPassword,
      records: records,
    );
    if (result.wasLegacyFormat) {
      // 偵測到舊版 PBKDF2 格式，背景自動升級為 Argon2id 格式重新寫回，
      // 不 await、不擋住解鎖流程；下次解鎖時就已經是新格式。
      unawaited(persist(session));
    }
    return session;
  }

  /// 將目前紀錄重新加密寫回檔案（沿用既有 salt，維持同一把主碼）
  static Future<bool> persist(VaultSession session) async {
    final file = await vaultFile(session.profile);
    final payload = utf8.encode(jsonEncode({
      'records': session.records.map((r) => r.toJson()).toList(),
    }));
    final bytes = await CryptoService.encryptToFile(
      masterPassword: session.masterPassword,
      salt: session.salt,
      plaintext: payload,
    );
    await _atomicWrite(file, bytes);
    return true;
  }

  static Future<void> _atomicWrite(File file, Uint8List bytes) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  static String generatePassword(int length) {
    if (length < 12) length = 12;
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    const alphabet = lower + upper + digits + symbolChars;
    final random = Random.secure();
    while (true) {
      final pwd = List.generate(length, (_) => alphabet[random.nextInt(alphabet.length)]).join();
      final hasLower = pwd.contains(RegExp('[a-z]'));
      final hasUpper = pwd.contains(RegExp('[A-Z]'));
      final hasDigit = pwd.contains(RegExp(r'[0-9]'));
      final hasSymbol = pwd.split('').any((c) => symbolChars.contains(c));
      if (hasLower && hasUpper && hasDigit && hasSymbol) {
        return pwd;
      }
    }
  }

  static String? weakPasswordReason(String password) {
    final lowered = password.toLowerCase();
    if (commonWeakPasswords.contains(lowered)) return '此密碼為常見弱密碼清單中的項目';
    if (password.length < 8) return '長度低於8字元';
    if (RegExp(r'^\d+$').hasMatch(password)) return '全部由數字組成';
    if (RegExp(r'^[a-z]+$').hasMatch(password)) return '全部由小寫字母組成';
    if (password.split('').toSet().length <= 3) return '字元重複性過高，多樣性不足';
    return null;
  }

  static String assessStrength(String password) {
    var score = 0;
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;
    final hasLower = password.contains(RegExp('[a-z]'));
    final hasUpper = password.contains(RegExp('[A-Z]'));
    if (hasLower && hasUpper) score += 1;
    if (password.contains(RegExp(r'[0-9]'))) score += 1;
    if (password.split('').any((c) => symbolChars.contains(c))) score += 1;
    final uniqueRatio = password.isEmpty ? 1.0 : password.split('').toSet().length / password.length;
    if (password.isNotEmpty && uniqueRatio < 0.6) score -= 1;
    if (score <= 1) return '弱';
    if (score <= 3) return '中';
    return '強';
  }
}
