import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// KDF 演算法識別碼，寫入檔案標頭，供解密時判斷要用哪種方式衍生金鑰。
enum KdfKind { pbkdf2, argon2id }

/// 檔案格式：
///
/// v2（舊，僅供讀取相容，不再用於寫入）：
///   MAGIC("PWV2", 4 bytes) + SALT(16 bytes) + NONCE(12 bytes) + CIPHERTEXT+TAG
///   金鑰衍生固定為 PBKDF2-HMAC-SHA256，60萬次迭代。
///
/// v3（新，所有寫入一律使用此格式）：
///   MAGIC("PWV3", 4 bytes) + KDF_ID(1 byte) + SALT(16 bytes) + NONCE(12 bytes) + CIPHERTEXT+TAG
///   KDF_ID = 0x01 固定代表 Argon2id（19 MiB 記憶體、2 次迭代、平行度 1，
///   依 OWASP Password Storage Cheat Sheet 建議基準值設定，
///   見 https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html）。
///
/// 兩種版本的加密演算法皆為 AES-256-GCM，差異只在金鑰衍生方式。
/// PBKDF2 與 Argon2id 的實際運算都丟到獨立 Isolate 執行，避免卡住 UI 執行緒。
class CryptoService {
  static const List<int> magicV2 = [0x50, 0x57, 0x56, 0x32]; // "PWV2"
  static const List<int> magicV3 = [0x50, 0x57, 0x56, 0x33]; // "PWV3"
  static const int saltSize = 16;
  static const int nonceSize = 12;

  /// 僅用於讀取舊版 v2 檔案，新檔案不再使用 PBKDF2。
  static const int pbkdf2Iterations = 600000;

  // Argon2id 參數（OWASP 建議基準值：m=19456 KiB / t=2 / p=1）。
  static const int argon2Memory = 19456; // KiB
  static const int argon2Iterations = 2;
  static const int argon2Parallelism = 1;
  static const int argon2HashLength = 32;

  static const int kdfIdArgon2id = 0x01;

  static final AesGcm _aesGcm = AesGcm.with256bits();

  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  static Future<SecretKey> deriveKey(
    String masterPassword,
    List<int> salt, {
    KdfKind kdf = KdfKind.argon2id,
  }) async {
    final bytes = await _deriveKeyBytes(kdf: kdf, masterPassword: masterPassword, salt: salt);
    return SecretKeyData(bytes);
  }

  /// 在獨立 Isolate 衍生金鑰，回傳原始位元組。
  /// 傳進 Isolate 的參數只包含可序列化的基本型別，演算法物件在 Isolate 內部才建立。
  static Future<Uint8List> _deriveKeyBytes({
    required KdfKind kdf,
    required String masterPassword,
    required List<int> salt,
  }) {
    final params = _DeriveKeyParams(
      kdf: kdf,
      password: masterPassword,
      salt: Uint8List.fromList(salt),
    );
    return Isolate.run(() => _deriveKeyBytesInIsolate(params));
  }

  /// 將明文加密並封裝為完整檔案位元組。新寫入一律使用 v3（Argon2id）格式。
  static Future<Uint8List> encryptToFile({
    required String masterPassword,
    required List<int> salt,
    required List<int> plaintext,
  }) async {
    final secretKey = await deriveKey(masterPassword, salt, kdf: KdfKind.argon2id);
    final nonce = randomBytes(nonceSize);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    final builder = BytesBuilder();
    builder.add(magicV3);
    builder.add([kdfIdArgon2id]);
    builder.add(salt);
    builder.add(secretBox.nonce);
    builder.add(secretBox.cipherText);
    builder.add(secretBox.mac.bytes);
    return builder.toBytes();
  }

  /// 解析檔案位元組並嘗試解密，同時支援 v2（PBKDF2）與 v3（Argon2id）格式。
  /// 主碼錯誤、檔案毀損、或無法辨識的 KDF 版本，一律回傳 null。
  static Future<DecryptResult?> decryptFile({
    required String masterPassword,
    required Uint8List fileBytes,
  }) async {
    if (fileBytes.length < magicV2.length) return null;

    final isV3 = _matchesMagic(fileBytes, magicV3);
    final isV2 = !isV3 && _matchesMagic(fileBytes, magicV2);
    if (!isV2 && !isV3) return null;

    final KdfKind kdf;
    int offset;
    if (isV3) {
      if (fileBytes.length < magicV3.length + 1) return null;
      final kdfId = fileBytes[magicV3.length];
      if (kdfId != kdfIdArgon2id) return null; // 未知的 KDF 版本，安全起見拒絕解析
      kdf = KdfKind.argon2id;
      offset = magicV3.length + 1;
    } else {
      kdf = KdfKind.pbkdf2;
      offset = magicV2.length;
    }

    if (fileBytes.length < offset + saltSize + nonceSize + 16) return null;
    final salt = fileBytes.sublist(offset, offset + saltSize);
    offset += saltSize;
    final nonce = fileBytes.sublist(offset, offset + nonceSize);
    offset += nonceSize;
    final remainder = fileBytes.sublist(offset);
    if (remainder.length < 16) return null;
    final cipherText = remainder.sublist(0, remainder.length - 16);
    final macBytes = remainder.sublist(remainder.length - 16);

    final secretKey = await deriveKey(masterPassword, salt, kdf: kdf);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    try {
      final clear = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      return DecryptResult(
        salt: Uint8List.fromList(salt),
        plaintext: Uint8List.fromList(clear),
        wasLegacyFormat: isV2,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _matchesMagic(Uint8List data, List<int> magic) {
    if (data.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }
}

class DecryptResult {
  final Uint8List salt;
  final Uint8List plaintext;

  /// true 代表這份檔案是用舊版 v2（PBKDF2）格式讀出來的。
  /// 呼叫端可以據此決定要不要在解鎖後自動升級成 v3（Argon2id）格式重新寫回。
  final bool wasLegacyFormat;

  DecryptResult({
    required this.salt,
    required this.plaintext,
    this.wasLegacyFormat = false,
  });
}

/// 傳給背景 Isolate 的參數，只能包含可跨 Isolate 傳遞的基本型別
/// （String、Uint8List、int、enum 等），不可包含演算法實例或其他複雜物件。
class _DeriveKeyParams {
  final KdfKind kdf;
  final String password;
  final Uint8List salt;
  _DeriveKeyParams({required this.kdf, required this.password, required this.salt});
}

/// 在背景 Isolate 內執行的實際運算函式。
/// 演算法物件（Pbkdf2 / Argon2id）在這裡才建立，不會有跨 Isolate 傳遞物件的問題。
Future<Uint8List> _deriveKeyBytesInIsolate(_DeriveKeyParams params) async {
  final KdfAlgorithm algorithm;
  switch (params.kdf) {
    case KdfKind.pbkdf2:
      algorithm = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: CryptoService.pbkdf2Iterations,
        bits: 256,
      );
      break;
    case KdfKind.argon2id:
      algorithm = Argon2id(
        memory: CryptoService.argon2Memory,
        parallelism: CryptoService.argon2Parallelism,
        iterations: CryptoService.argon2Iterations,
        hashLength: CryptoService.argon2HashLength,
      );
      break;
  }
  final secretKey = await algorithm.deriveKeyFromPassword(
    password: params.password,
    nonce: params.salt,
  );
  final bytes = await secretKey.extractBytes();
  return Uint8List.fromList(bytes);
}
