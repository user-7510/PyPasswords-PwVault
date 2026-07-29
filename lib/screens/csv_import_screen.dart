import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/record.dart';
import '../services/csv_service.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  String? filePath;
  List<PasswordRecord>? preview;
  String? error;
  bool loading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      filePath = result.files.single.path;
      loading = true;
      error = null;
      preview = null;
    });
    try {
      final imported = await CsvService.importFromFile(File(filePath!));
      setState(() {
        preview = imported.records;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'CSV解析失敗: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('匯入CSV')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('CSV欄位需包含：帳戶類型,帳號名稱,密碼,連結帳戶,姓名,備註'),
            const Text('備註欄可重複多欄（例如 備註1、備註2），同一欄內亦可用 ; 或 ； 分隔多筆備註'),
            const SizedBox(height: 16),
            OutlinedButton.icon(icon: const Icon(Icons.file_open), label: const Text('選擇CSV檔案'), onPressed: _pickFile),
            const SizedBox(height: 16),
            if (loading) const CircularProgressIndicator(),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            if (preview != null) ...[
              Text('已解析 ${preview!.length} 筆紀錄：'),
              Expanded(
                child: ListView.builder(
                  itemCount: preview!.length,
                  itemBuilder: (context, index) {
                    final r = preview![index];
                    return ListTile(
                      dense: true,
                      title: Text('[${r.accountType}] ${r.accountName}'),
                      subtitle: Text(r.name),
                    );
                  },
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, preview),
                child: Text('確認匯入 ${preview!.length} 筆'),
              ),
              const Text(
                '提醒：來源CSV檔案本身為明文，匯入完成後建議自行安全刪除該檔案',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
