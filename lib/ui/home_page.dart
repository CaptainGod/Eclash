import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import 'nodes_page.dart';
import 'subscription_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Eclash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.link, color: Colors.white70),
            tooltip: '订阅管理',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SubscriptionPage()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 状态指示灯 + 开关按钮
            GestureDetector(
              onTap: state.loading ? null : () => state.toggleProxy(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.proxyEnabled
                      ? const Color(0xFF0F3460)
                      : const Color(0xFF2D2D44),
                  boxShadow: state.proxyEnabled
                      ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 40, spreadRadius: 10)]
                      : [],
                ),
                child: state.loading
                    ? const CircularProgressIndicator(color: Colors.white54)
                    : Icon(
                        Icons.power_settings_new,
                        size: 72,
                        color: state.proxyEnabled ? Colors.blueAccent : Colors.white38,
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // 状态文字
            Text(
              state.statusMessage,
              style: TextStyle(
                color: state.proxyEnabled ? Colors.blueAccent : Colors.white54,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 48),

            // 节点选择入口（仅连接时显示）
            if (state.proxyEnabled && state.groups.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3460),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.alt_route, color: Colors.white),
                label: const Text('选择节点', style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const NodesPage()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
