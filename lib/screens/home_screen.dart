import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/record.dart';
import '../services/vault_service.dart';
import 'backup_screen.dart';
import 'csv_import_screen.dart';
import 'password_generator_screen.dart';
import 'profile_screen.dart';
import 'record_form_screen.dart';

class HomeScreen extends StatefulWidget {
  final VaultSession session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String keyword = '';
  bool selectionMode = false;
  final Set<String> selectedIds = {};

  List<PasswordRecord> get filtered {
    if (keyword.isEmpty) return widget.session.records;
    final lower = keyword.toLowerCase();
    return widget.session.records
        .where((r) => r.accountName.toLowerCase().contains(lower))
        .toList();
  }

  Future<void> _openRecord(PasswordRecord record) async {
    if (selectionMode) {
      setState(() {
        if (selectedIds.contains(record.id)) {
          selectedIds.remove(record.id);
        } else {
          selectedIds.add(record.id);
        }
      });
      return;
    }
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.accountName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('帳戶類型', record.accountType),
            _detailRow('連結帳戶', record.linkedAccount),
            _detailRow('姓名', record.name),
            Row(
              children: [
                Expanded(child: _detailRow('密碼', record.password)),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: record.password));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製密碼')),
                    );
                  },
                ),
              ],
            ),
            if (record.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('備註:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...record.notes.map((n) => Text('• $n')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editRecord(record);
            },
            child: const Text('編輯'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label: $value'),
    );
  }

  Future<void> _addRecord() async {
    final result = await Navigator.push<PasswordRecord>(
      context,
      MaterialPageRoute(builder: (_) => const RecordFormScreen()),
    );
    if (result != null) {
      widget.session.records.add(result);
      await VaultService.persist(widget.session);
      setState(() {});
    }
  }

  Future<void> _editRecord(PasswordRecord record) async {
    final result = await Navigator.push<PasswordRecord>(
      context,
      MaterialPageRoute(builder: (_) => RecordFormScreen(existing: record)),
    );
    if (result != null) {
      await VaultService.persist(widget.session);
      setState(() {});
    }
  }

  Future<void> _deleteSelected() async {
    final targets = widget.session.records.where((r) => selectedIds.contains(r.id)).toList();
    if (targets.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('即將刪除以下 ${targets.length} 筆紀錄:'),
              const SizedBox(height: 8),
              ...targets.map((t) => Text('• [${t.accountType}] ${t.accountName}（密碼: ${t.password}）')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.session.records.removeWhere((r) => selectedIds.contains(r.id));
      await VaultService.persist(widget.session);
      setState(() {
        selectedIds.clear();
        selectionMode = false;
      });
    }
  }

  void _lockAndExit() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.session.profile}${selectionMode ? '（已選 ${selectedIds.length} 筆）' : ''}'),
        actions: [
          if (selectionMode) ...[
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelected),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                selectionMode = false;
                selectedIds.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: '多選刪除',
              onPressed: () => setState(() => selectionMode = true),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'generate':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordGeneratorScreen()));
                    break;
                  case 'backup':
                    final imported = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => BackupScreen(session: widget.session)),
                    );
                    if (imported == true) {
                      // 匯入備份後檔案內容已被取代，需重新以主碼解鎖才能確保資料一致
                      _lockAndExit();
                      return;
                    }
                    setState(() {});
                    break;
                  case 'csv':
                    final imported = await Navigator.push<List<PasswordRecord>>(
                      context,
                      MaterialPageRoute(builder: (_) => const CsvImportScreen()),
                    );
                    if (imported != null && imported.isNotEmpty) {
                      widget.session.records.addAll(imported);
                      await VaultService.persist(widget.session);
                      setState(() {});
                    }
                    break;
                  case 'switch':
                    _lockAndExit();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'generate', child: Text('生成密碼')),
                PopupMenuItem(value: 'backup', child: Text('匯出／匯入備份')),
                PopupMenuItem(value: 'csv', child: Text('匯入CSV')),
                PopupMenuItem(value: 'switch', child: Text('切換設定檔／鎖定')),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋帳號名稱',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => keyword = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('目前沒有任何紀錄'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      final selected = selectedIds.contains(record.id);
                      return ListTile(
                        leading: selectionMode
                            ? Checkbox(value: selected, onChanged: (_) => _openRecord(record))
                            : const CircleAvatar(child: Icon(Icons.lock_outline)),
                        title: Text(record.accountName.isEmpty ? '（未命名）' : record.accountName),
                        subtitle: Text('${record.accountType}${record.name.isEmpty ? '' : ' · ${record.name}'}'),
                        trailing: selectionMode
                            ? null
                            : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editRecord(record)),
                        onTap: () => _openRecord(record),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: selectionMode
          ? null
          : FloatingActionButton(onPressed: _addRecord, child: const Icon(Icons.add)),
    );
  }
}
