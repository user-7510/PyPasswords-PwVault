import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import 'setup_screen.dart';
import 'unlock_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> profiles = [];
  final TextEditingController newProfileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await VaultService.listProfiles();
    setState(() => profiles = list);
  }

  Future<void> _openProfile(String profile) async {
    final exists = await VaultService.profileExists(profile);
    if (!mounted) return;
    if (exists) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UnlockScreen(profile: profile)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SetupScreen(profile: profile)),
      );
    }
    _loadProfiles();
  }

  void _createProfile() {
    final name = newProfileController.text.trim();
    if (!VaultService.isValidProfileName(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定檔名稱不合法，僅允許字母、數字、底線、連字號、中文字元')),
      );
      return;
    }
    newProfileController.clear();
    _openProfile(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('選擇設定檔')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('現有設定檔', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: profiles.isEmpty
                  ? const Center(child: Text('目前尚無任何設定檔'))
                  : ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: Text(profile),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openProfile(profile),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('建立新設定檔', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newProfileController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '輸入新設定檔名稱',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _createProfile, child: const Text('建立/開啟')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
