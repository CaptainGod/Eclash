import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';

class NodesPage extends StatelessWidget {
  const NodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final groups = state.groups;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('节点选择', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => state.refreshGroups(),
          )
        ],
      ),
      body: groups.isEmpty
          ? const Center(child: Text('没有可用的节点组', style: TextStyle(color: Colors.white54)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: groups.entries.map((entry) {
                final group = entry.value;
                return Card(
                  color: const Color(0xFF16213E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    title: Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('当前: ${group.current}', style: const TextStyle(color: Colors.blueAccent)),
                    iconColor: Colors.white54,
                    collapsedIconColor: Colors.white54,
                    children: group.members.map((node) {
                      final isSelected = node == group.current;
                      return ListTile(
                        title: Text(node, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white70)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
                        onTap: () => state.selectNode(group.name, node),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
