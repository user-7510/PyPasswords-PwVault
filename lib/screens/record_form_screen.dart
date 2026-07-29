import 'package:flutter/material.dart';

import '../models/record.dart';
import '../services/vault_service.dart';

class RecordFormScreen extends StatefulWidget {
  final PasswordRecord? existing;
  const RecordFormScreen({super.key, this.existing});

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  late TextEditingController accountTypeController;
  late TextEditingController accountNameController;
  late TextEditingController passwordController;
  late TextEditingController linkedAccountController;
  late TextEditingController nameController;
  late TextEditingController newNoteController;
  late List<String> notes;
  bool obscure = true;
  String? strength;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    accountTypeController = TextEditingController(text: r?.accountType ?? '');
    accountNameController = TextEditingController(text: r?.accountName ?? '');
    passwordController = TextEditingController(text: r?.password ?? '');
    linkedAccountController = TextEditingController(text: r?.linkedAccount ?? '');
    nameController = TextEditingController(text: r?.name ?? '');
    newNoteController = TextEditingController();
    notes = List<String>.from(r?.notes ?? []);
    if (passwordController.text.isNotEmpty) {
      strength = VaultService.assessStrength(passwordController.text);
    }
  }

  void _generatePassword() {
    setState(() {
      passwordController.text = VaultService.generatePassword(20);
      strength = VaultService.assessStrength(passwordController.text);
    });
  }

  void _addNote() {
    final text = newNoteController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      notes.add(text);
      newNoteController.clear();
    });
  }

  void _save() {
    final record = widget.existing ?? PasswordRecord.newRecord();
    record.accountType = accountTypeController.text.trim();
    record.accountName = accountNameController.text.trim();
    record.password = passwordController.text;
    record.linkedAccount = linkedAccountController.text.trim();
    record.name = nameController.text.trim();
    record.notes = notes;
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '編輯紀錄' : '新增紀錄'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: accountTypeController,
            decoration: const InputDecoration(labelText: '帳戶類型', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: accountNameController,
            decoration: const InputDecoration(labelText: '帳號名稱', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: obscure,
            onChanged: (v) => setState(() => strength = v.isEmpty ? null : VaultService.assessStrength(v)),
            decoration: InputDecoration(
              labelText: '密碼',
              border: const OutlineInputBorder(),
              helperText: strength == null ? null : '強度評估: $strength',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                  IconButton(icon: const Icon(Icons.autorenew), tooltip: '自動生成', onPressed: _generatePassword),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: linkedAccountController,
            decoration: const InputDecoration(labelText: '連結帳戶（可留空）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '姓名（可留空）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('備註', style: Theme.of(context).textTheme.titleMedium),
          ...notes.asMap().entries.map((entry) {
            final index = entry.key;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => notes.removeAt(index)),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newNoteController,
                  decoration: const InputDecoration(hintText: '新增備註', border: OutlineInputBorder()),
                  onSubmitted: (_) => _addNote(),
                ),
              ),
              IconButton(icon: const Icon(Icons.add), onPressed: _addNote),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('儲存')),
        ],
      ),
    );
  }
}
