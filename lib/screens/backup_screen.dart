import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../services/vault_service.dart';

class BackupScreen extends StatefulWidget {
  final VaultSession session;
  const BackupScreen({super.key, required this.session});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? statusText;

  Future<void> _exportBackup() async {
    final savePath = await FilePicker.saveFile(
      dialogTitle: '選擇備份儲存位置',
      fileName: '${widget.session.profile}_backup.pwv2',
    );
    if (savePath == null) return;
    final result = await BackupService.exportBackup(widget.session.profile, savePath);
    setState(() => statusText = result.message);
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final srcPath = result.files.single.path!;

    var proceedWithoutChecksum = false;
    var overwriteConfirmed = false;

    var attempt = await BackupService.importBackup(
      profile: widget.session.profile,
      srcPath: srcPath,
      overwriteConfirmed: overwriteConfirmed,
      proceedWithoutChecksum: proceedWithoutChecksum,
    );

    if (attempt.message == 'NEED_CHECKSUM_CONFIRM') {
      final confirm = await _confirmDialog('找不到對應的 .sha256 checksum 檔案，無法驗證完整性，仍要繼續匯入嗎？');
      if (confirm != true) return;
      proceedWithoutChecksum = true;
      attempt = await BackupService.importBackup(
        profile: widget.session.profile,
        srcPath: srcPath,
        overwriteConfirmed: overwriteConfirmed,
        proceedWithoutChecksum: proceedWithoutChecksum,
      );
    }

    if (attempt.message == 'NEED_OVERWRITE_CONFIRM') {
      final confirm = await _confirmDialog('匯入將覆蓋此設定檔現有資料庫，是否繼續？');
      if (confirm != true) return;
      overwriteConfirmed = true;
      attempt = await BackupService.importBackup(
        profile: widget.session.profile,
        srcPath: srcPath,
        overwriteConfirmed: overwriteConfirmed,
        proceedWithoutChecksum: proceedWithoutChecksum,
      );
    }

    setState(() => statusText = attempt.message);
    if (attempt.success && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<bool?> _confirmDialog(String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('繼續')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('匯出／匯入備份')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('匯出的檔案本身仍是加密狀態，沒有對應主碼無法讀取，但仍建議妥善保管於可控管的儲存位置。'),
            const SizedBox(height: 16),
            FilledButton.icon(icon: const Icon(Icons.upload), label: const Text('匯出備份'), onPressed: _exportBackup),
            const SizedBox(height: 12),
            OutlinedButton.icon(icon: const Icon(Icons.download), label: const Text('匯入備份（將覆蓋目前設定檔）'), onPressed: _importBackup),
            if (statusText != null) ...[
              const SizedBox(height: 16),
              Text(statusText!),
            ],
          ],
        ),
      ),
    );
  }
}
