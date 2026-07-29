import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  final String profile;
  const SetupScreen({super.key, required this.profile});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final master1 = TextEditingController();
  final master2 = TextEditingController();
  bool weakCheck = true;
  String? errorText;
  bool obscure = true;

  Future<void> _confirmSetup() async {
    if (master1.text != master2.text) {
      setState(() => errorText = '兩次輸入不一致');
      return;
    }
    if (master1.text.isEmpty) {
      setState(() => errorText = '主碼不可為空');
      return;
    }
    if (weakCheck) {
      final reason = VaultService.weakPasswordReason(master1.text);
      if (reason != null) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('弱主碼警告'),
            content: Text('$reason\n仍要使用此主碼嗎？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('重新設定')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('仍要使用')),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }
    await VaultService.setupMasterPassword(widget.profile, master1.text);
    final session = await VaultService.unlock(widget.profile, master1.text);
    if (!mounted || session == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('設定主碼：${widget.profile}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('此設定檔尚未建立，請設定主碼。'),
            const SizedBox(height: 4),
            const Text(
              '警告：主碼一旦遺失，此設定檔所有紀錄將永久無法復原，本程式不提供任何救援機制。',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: master1,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: '設定主碼',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: master2,
              obscureText: obscure,
              decoration: const InputDecoration(labelText: '再次輸入主碼確認', border: OutlineInputBorder()),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            ],
            SwitchListTile(
              value: weakCheck,
              onChanged: (v) => setState(() => weakCheck = v),
              title: const Text('啟用離線弱密碼檢查'),
              subtitle: const Text('純本機規則比對，不連網查詢'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _confirmSetup, child: const Text('確定設定')),
          ],
        ),
      ),
    );
  }
}
