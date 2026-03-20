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
        title: const Text('Eclash',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.link, color: Colors.white70),
            tooltip: '订阅管理',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          // 模式选择（直连/规则/全局）
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: _ModeSelector(
              current: state.mode,
              onChanged: state.changeMode,
            ),
          ),

          // 主区域：开关按钮
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: state.loading || !state.hasConfig
                        ? null
                        : () => state.toggleProxy(),
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
                            ? [
                                BoxShadow(
                                    color:
                                        Colors.blueAccent.withOpacity(0.6),
                                    blurRadius: 40,
                                    spreadRadius: 10)
                              ]
                            : [],
                      ),
                      child: state.loading
                          ? const CircularProgressIndicator(
                              color: Colors.white54)
                          : Icon(
                              Icons.power_settings_new,
                              size: 72,
                              color: state.proxyEnabled
                                  ? Colors.blueAccent
                                  : (state.hasConfig
                                      ? Colors.white54
                                      : Colors.white12),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.hasConfig ? state.statusMessage : '请先导入订阅',
                    style: TextStyle(
                      color: state.proxyEnabled
                          ? Colors.blueAccent
                          : Colors.white54,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部：节点选择（有配置就显示）
          if (state.hasConfig)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.proxyEnabled
                        ? const Color(0xFF0F3460)
                        : const Color(0xFF2D2D44),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.alt_route, color: Colors.white70),
                  label: Text(
                    state.proxyEnabled
                        ? '切换节点'
                        : state.hasOfflineNodes
                            ? '选择节点（开启前生效）'
                            : '查看策略组（连接后加载节点）',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  onPressed: () async {
                    // 未连接时先从本地配置加载节点列表
                    if (!state.proxyEnabled) await state.loadGroupsFromConfig();
                    if (!context.mounted) return;
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const NodesPage()));
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _ModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const modes = [
      ('direct', '直连'),
      ('rule', '规则'),
      ('global', '全局'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: modes.map((m) {
          final selected = current == m.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Colors.blueAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  m.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white38,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
