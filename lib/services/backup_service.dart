import 'dart:io';

import 'package:crypto/crypto.dart';

import 'vault_service.dart';

class BackupResult {
  final bool success;
  final String message;
  BackupResult(this.success, this.message);
}

class BackupService {
  static String sha256Hex(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// 匯出目前設定檔的加密資料庫到指定路徑，並產生 .sha256 校驗檔
  static Future<BackupResult> exportBackup(String profile, String destPath) async {
    final source = await VaultService.vaultFile(profile);
    if (!await source.exists()) {
      return BackupResult(false, '此設定檔尚未建立資料庫，無法匯出');
    }
    final data = await source.readAsBytes();
    final checksum = sha256Hex(data);
    final destFile = File(destPath);
    final checksumFile = File('$destPath.sha256');
    try {
      await destFile.writeAsBytes(data, flush: true);
      await checksumFile.writeAsString(checksum, flush: true);
    } catch (e) {
      return BackupResult(false, '寫入備份失敗: $e');
    }
    return BackupResult(true, '已匯出備份至 $destPath，checksum 已存於 ${checksumFile.path}');
  }

  /// 從備份檔還原到指定設定檔，overwriteConfirmed 需由呼叫端先徵得使用者同意
  static Future<BackupResult> importBackup({
    required String profile,
    required String srcPath,
    required bool overwriteConfirmed,
    required bool proceedWithoutChecksum,
  }) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      return BackupResult(false, '備份檔案不存在');
    }
    final data = await srcFile.readAsBytes();
    final checksumFile = File('$srcPath.sha256');
    if (await checksumFile.exists()) {
      final expected = (await checksumFile.readAsString()).trim();
      if (expected != sha256Hex(data)) {
        return BackupResult(false, '警告：checksum 不符，備份檔案可能已損毀或被竄改，已中止匯入');
      }
    } else if (!proceedWithoutChecksum) {
      return BackupResult(false, 'NEED_CHECKSUM_CONFIRM');
    }
    final target = await VaultService.vaultFile(profile);
    if (await target.exists() && !overwriteConfirmed) {
      return BackupResult(false, 'NEED_OVERWRITE_CONFIRM');
    }
    await target.writeAsBytes(data, flush: true);
    return BackupResult(true, '匯入完成');
  }
}
