import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

class UnlockScreen extends StatefulWidget {
  final String profile;
  const UnlockScreen({super.key, required this.profile});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final masterController = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? errorText;

  Future<void> _unlock() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    final session = await VaultService.unlock(widget.profile, masterController.text);
    setState(() => loading = false);
    if (session == null) {
      setState(() => errorText = '主碼錯誤，或資料已損毀');
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
    );
  }

  Future<void> _resetProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重設主碼'),
        content: const Text('重設將清空此設定檔所有資料，是否繼續？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('繼續')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SetupScreen(profile: widget.profile)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('解鎖：${widget.profile}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: masterController,
              obscureText: obscure,
              autofocus: true,
              onSubmitted: (_) => _unlock(),
              decoration: InputDecoration(
                labelText: '輸入主碼',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : _unlock,
              child: loading ? const CircularProgressIndicator() : const Text('解鎖'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _resetProfile, child: const Text('忘記主碼？重設此設定檔（將清空資料）')),
          ],
        ),
      ),
    );
  }
}
