class ProxyNode {
  final String name;
  final String type;
  final bool alive;
  final int? delay;

  ProxyNode({
    required this.name,
    required this.type,
    this.alive = false,
    this.delay,
  });

  factory ProxyNode.fromJson(String name, Map<String, dynamic> json) {
    return ProxyNode(
      name: name,
      type: json['type'] ?? 'Unknown',
      alive: json['history'] != null &&
          (json['history'] as List).isNotEmpty,
      delay: json['history'] != null && (json['history'] as List).isNotEmpty
          ? (json['history'] as List).last['delay']
          : null,
    );
  }
}

class ProxyGroup {
  final String name;
  final String type;
  final String current;
  final List<String> members;

  ProxyGroup({
    required this.name,
    required this.type,
    required this.current,
    required this.members,
  });

  factory ProxyGroup.fromJson(String name, Map<String, dynamic> json) {
    return ProxyGroup(
      name: name,
      type: json['type'] ?? 'Selector',
      current: json['now'] ?? '',
      members: List<String>.from(json['all'] ?? []),
    );
  }
}
