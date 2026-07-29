import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/vault_service.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() => _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double length = 20;
  String password = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    setState(() => password = VaultService.generatePassword(length.round()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('生成密碼')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  password,
                  style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('長度: ${length.round()}'),
            Slider(
              value: length,
              min: 12,
              max: 64,
              divisions: 52,
              label: length.round().toString(),
              onChanged: (v) => setState(() => length = v),
              onChangeEnd: (_) => _generate(),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.autorenew),
                    label: const Text('重新生成'),
                    onPressed: _generate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('複製'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製到剪貼簿')));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
