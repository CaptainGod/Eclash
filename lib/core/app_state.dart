import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import '../models/proxy_node.dart';
import 'mihomo_service.dart';
import 'subscription_service.dart';

class AppState extends ChangeNotifier {
  final MihomoService _mihomo = MihomoService();
  final SubscriptionService _sub = SubscriptionService();

  bool _proxyEnabled = false;
  bool _loading = false;
  String _statusMessage = '未连接';
  Map<String, ProxyGroup> _groups = {};
  List<String> _groupOrder = [];   // 从 YAML 读取的原始顺序
  String? _savedCode;
  String _mode = 'rule';           // direct / rule / global

  bool get proxyEnabled => _proxyEnabled;
  bool get loading => _loading;
  String get statusMessage => _statusMessage;
  String get mode => _mode;
  String? get savedCode => _savedCode;
  bool get hasConfig => _savedCode != null;

  /// 按 YAML 原始顺序返回策略组
  List<ProxyGroup> get orderedGroups {
    if (_groupOrder.isEmpty) return _groups.values.toList();
    final result = <ProxyGroup>[];
    for (final name in _groupOrder) {
      if (_groups.containsKey(name)) result.add(_groups[name]!);
    }
    return result;
  }

  Future<void> init() async {
    _savedCode = await _sub.getSavedCode();
    if (_savedCode != null) await _loadGroupOrder();
    notifyListeners();
  }

  /// 解析配置文件中 proxy-groups 的顺序
  Future<void> _loadGroupOrder() async {
    try {
      final file = await _sub.getConfigFile();
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      final groups = yaml['proxy-groups'];
      if (groups is YamlList) {
        _groupOrder = groups
            .where((g) => g is YamlMap && g['name'] != null)
            .map<String>((g) => g['name'].toString())
            .toList();
      }
    } catch (_) {}
  }

  Future<bool> downloadSubscription(String code) async {
    _setLoading(true, '正在下载配置...');
    final ok = await _sub.downloadConfig(code);
    if (ok) {
      _savedCode = code;
      await _loadGroupOrder();
    }
    _setLoading(false, ok ? '配置下载成功' : '下载失败，请检查订阅码');
    return ok;
  }

  Future<void> toggleProxy() async {
    if (_loading) return;
    if (_proxyEnabled) {
      _setLoading(true, '正在关闭...');
      await _mihomo.stop();
      _proxyEnabled = false;
      _groups = {};
      _setLoading(false, '未连接');
    } else {
      _setLoading(true, '正在连接...');
      final ok = await _mihomo.start();
      if (ok) {
        _proxyEnabled = true;
        await Future.delayed(const Duration(milliseconds: 1200));
        await refreshGroups();
        await _syncMode();
        _setLoading(false, '已连接');
      } else {
        _setLoading(false, '连接失败，请先导入订阅');
      }
    }
  }

  Future<void> refreshGroups() async {
    _groups = await _mihomo.getGroups();
    notifyListeners();
  }

  Future<void> selectNode(String group, String node) async {
    final ok = await _mihomo.selectNode(group, node);
    if (ok) await refreshGroups();
  }

  Future<void> changeMode(String mode) async {
    _mode = mode;
    notifyListeners();
    if (_proxyEnabled) await _mihomo.setMode(mode);
  }

  Future<void> _syncMode() async {
    await _mihomo.setMode(_mode);
  }

  /// 未连接时从本地 YAML 解析节点列表（仅用于展示，不调用 API）
  Future<void> loadGroupsFromConfig() async {
    try {
      final file = await _sub.getConfigFile();
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      final rawGroups = yaml['proxy-groups'];
      if (rawGroups is! YamlList) return;

      final result = <String, ProxyGroup>{};
      final order = <String>[];
      for (final g in rawGroups) {
        if (g is! YamlMap) continue;
        final name = g['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        final type = g['type']?.toString() ?? 'Selector';
        final proxies = (g['proxies'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        result[name] = ProxyGroup(
          name: name,
          type: type,
          current: proxies.isNotEmpty ? proxies.first : '',
          members: proxies,
        );
        order.add(name);
      }
      _groups = result;
      _groupOrder = order;
      notifyListeners();
    } catch (_) {}
  }

  void _setLoading(bool value, String message) {
    _loading = value;
    _statusMessage = message;
    notifyListeners();
  }
}
