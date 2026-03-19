import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _controller = TextEditingController(text: state.savedCode ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('订阅管理', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('订阅码', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '请输入订阅码',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF16213E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: state.loading
                    ? null
                    : () async {
                        final code = _controller.text.trim();
                        if (code.isEmpty) return;
                        final ok = await state.downloadSubscription(code);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? '订阅更新成功！' : '下载失败，请检查订阅码'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ));
                        if (ok) Navigator.pop(context);
                      },
                child: state.loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('保存并下载配置', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            if (state.savedCode != null) ...[
              const SizedBox(height: 32),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const Text('当前订阅', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Text(state.savedCode!, style: const TextStyle(color: Colors.blueAccent, fontSize: 15)),
            ]
          ],
        ),
      ),
    );
  }
}
