import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../models/proxy_node.dart';

class NodesPage extends StatelessWidget {
  const NodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final groups = state.orderedGroups;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('节点选择', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (state.proxyEnabled)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () => state.refreshGroups(),
            ),
        ],
      ),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      state.configError ?? '没有找到策略组',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, i) => _GroupCard(
                group: groups[i],
                isConnected: state.proxyEnabled,
                onSelect: (node) => state.selectNode(groups[i].name, node),
              ),
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ProxyGroup group;
  final bool isConnected;
  final ValueChanged<String> onSelect;

  const _GroupCard({
    required this.group,
    required this.isConnected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(group.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(group.type,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ],
        ),
        subtitle: Text(
          '当前: ${group.current}',
          style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        children: group.members.isEmpty
            ? [
                ListTile(
                  dense: true,
                  leading: Icon(
                    isConnected ? Icons.sync : Icons.cloud_download_outlined,
                    color: Colors.white24,
                    size: 16,
                  ),
                  title: Text(
                    isConnected ? '节点加载中...' : '请先连接，节点由 proxy-providers 自动加载',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ]
            : group.members.map((node) {
                final isSelected = node == group.current;
                return ListTile(
                  dense: true,
                  title: Text(node,
                      style: TextStyle(
                          color: isSelected ? Colors.blueAccent : Colors.white70,
                          fontSize: 14)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: Colors.blueAccent, size: 18)
                      : (isConnected
                          ? const Icon(Icons.radio_button_unchecked,
                              color: Colors.white24, size: 18)
                          : null),
                  onTap: () {
                    onSelect(node);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
      ),
    );
  }
}
