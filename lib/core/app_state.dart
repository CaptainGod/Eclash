import 'dart:async';
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
  bool _prefetchingNodes = false;
  String _statusMessage = '未连接';
  Map<String, ProxyGroup> _groups = {};
  List<String> _groupOrder = [];
  String? _savedCode;
  String _mode = 'rule';
  String? _configError;
  Timer? _healthTimer;

  bool get proxyEnabled => _proxyEnabled;
  bool get loading => _loading;
  bool get prefetchingNodes => _prefetchingNodes;
  String get statusMessage => _statusMessage;
  String get mode => _mode;
  String? get savedCode => _savedCode;
  bool get hasConfig => _savedCode != null;
  String? get configError => _configError;
  bool get hasOfflineNodes =>
      _groups.values.any((g) => g.members.isNotEmpty);

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

  Future<void> _loadGroupOrder() async {
    try {
      final file = await _sub.getConfigFile();
      if (!file.existsSync()) return;
      final doc = loadYaml(await file.readAsString());
      final groups = doc['proxy-groups'];
      if (groups is YamlList) {
        _groupOrder = groups
            .where((g) => g is YamlMap && g['name'] != null)
            .map<String>((g) => g['name'].toString())
            .toList();
      }
    } catch (_) {}
  }

  Future<bool> downloadSubscription(String codeOrUrl) async {
    _setLoading(true, '正在下载配置...');
    final ok = await _sub.downloadConfig(codeOrUrl);
    if (ok) {
      _savedCode = codeOrUrl;
      await _loadGroupOrder();
    }
    _setLoading(false, ok ? '配置下载成功' : '下载失败，请检查订阅地址');
    return ok;
  }

  Future<void> toggleProxy() async {
    if (_loading) return;

    if (_proxyEnabled) {
      _setLoading(true, '正在关闭...');
      _stopHealthCheck();
      await _mihomo.stop();
      _proxyEnabled = false;
      _groups = {};
      _setLoading(false, '未连接');
      return;
    }

    _setLoading(true, '正在连接...');
    final ok = await _mihomo.start();
    if (!ok) {
      _setLoading(false, '连接失败，请先导入订阅');
      return;
    }

    bool apiReady = false;
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!await _mihomo.checkRunning()) break;
      if (await _mihomo.isApiReady()) { apiReady = true; break; }
    }

    if (!apiReady) {
      await _mihomo.stop();
      _setLoading(false, '连接失败，mihomo 未能启动');
      return;
    }

    _proxyEnabled = true;
    await _syncMode();
    _setLoading(false, '已连接 · 加载节点...');
    _startHealthCheck();
    _pollForNodes();
  }

  Future<void> _pollForNodes() async {
    for (var i = 0; i < 60; i++) {
      if (!_proxyEnabled) return;
      await refreshGroups();
      if (_groups.isNotEmpty) {
        _statusMessage = '已连接';
        notifyListeners();
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    if (_proxyEnabled) {
      _statusMessage = '已连接';
      notifyListeners();
    }
  }

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_proxyEnabled) { _stopHealthCheck(); return; }
      if (!await _mihomo.checkRunning()) {
        _proxyEnabled = false;
        _groups = {};
        _stopHealthCheck();
        _setLoading(false, '连接已断开');
      }
    });
  }

  void _stopHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = null;
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

  Future<void> loadGroupsFromConfig() async {
    _configError = null;
    try {
      final file = await _sub.getConfigFile();
      if (!file.existsSync()) {
        _configError = '配置文件不存在，请重新下载订阅';
        notifyListeners();
        return;
      }

      dynamic doc;
      try {
        doc = loadYaml(await file.readAsString());
      } catch (e) {
        _configError = 'YAML 解析失败：$e';
        notifyListeners();
        return;
      }

      final rawGroups = doc['proxy-groups'] ?? doc['proxy-group'];
      if (rawGroups == null) {
        _configError = '配置文件中没有找到 proxy-groups';
        notifyListeners();
        return;
      }
      if (rawGroups is! YamlList) {
        _configError = 'proxy-groups 格式错误';
        notifyListeners();
        return;
      }

      final result = <String, ProxyGroup>{};
      final order = <String>[];
      for (final g in rawGroups) {
        if (g is! YamlMap) continue;
        final name = g['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        final type = g['type']?.toString() ?? 'Selector';
        final proxiesRaw = g['proxies'];
        final proxies = proxiesRaw is YamlList
            ? proxiesRaw.map((e) => e.toString()).toList()
            : <String>[];
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

      // 若所有组的成员都为空（proxy-providers 配置），在后台拉取实际节点
      final needsPrefetch = result.values.every((g) => g.members.isEmpty);
      if (needsPrefetch && result.isNotEmpty) {
        notifyListeners();
        _prefetchProviderNodes(doc, result, order);
      } else {
        notifyListeners();
      }
    } catch (e) {
      _configError = '加载失败：$e';
      notifyListeners();
    }
  }

  /// 后台从 proxy-providers URL 拉取节点，按各策略组的 filter 正则分配成员。
  /// App 流量已通过 addDisallowedApplication 绕过 VPN，本方法始终走直连。
  Future<void> _prefetchProviderNodes(
    dynamic doc,
    Map<String, ProxyGroup> groups,
    List<String> order,
  ) async {
    _prefetchingNodes = true;
    _configError = null;
    notifyListeners();

    final allNames = await _sub.fetchProviderProxyNames(doc);

    if (allNames.isEmpty) {
      _prefetchingNodes = false;
      _configError = '节点列表为空，请检查 proxy-providers 订阅地址';
      notifyListeners();
      return;
    }

    final rawGroups = doc['proxy-groups'];
    if (rawGroups is! YamlList) {
      _prefetchingNodes = false;
      notifyListeners();
      return;
    }

    for (final g in rawGroups) {
      if (g is! YamlMap) continue;
      final name = g['name']?.toString() ?? '';
      if (!groups.containsKey(name)) continue;
      if (g['include-all'] != true) continue;

      final filterStr = g['filter']?.toString();
      List<String> filtered;
      if (filterStr != null && filterStr.isNotEmpty) {
        try {
          final re = RegExp(filterStr);
          filtered = allNames.where((n) => re.hasMatch(n)).toList();
        } catch (_) {
          filtered = allNames;
        }
      } else {
        filtered = allNames;
      }

      // 保留原有静态成员（其他组的引用），把实际节点追加在后
      final existing = groups[name]!.members;
      final merged = [
        ...existing,
        ...filtered.where((n) => !existing.contains(n)),
      ];
      groups[name] = ProxyGroup(
        name: name,
        type: groups[name]!.type,
        current: merged.isNotEmpty ? merged.first : '',
        members: merged,
      );
    }

    _groups = groups;
    _groupOrder = order;
    _prefetchingNodes = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopHealthCheck();
    super.dispose();
  }

  void _setLoading(bool value, String message) {
    _loading = value;
    _statusMessage = message;
    notifyListeners();
  }
}
