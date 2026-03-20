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
  String _statusMessage = '未连接';
  Map<String, ProxyGroup> _groups = {};
  List<String> _groupOrder = [];
  String? _savedCode;
  String _mode = 'rule';
  String? _configError;
  Timer? _healthTimer;

  bool get proxyEnabled => _proxyEnabled;
  bool get loading => _loading;
  String get statusMessage => _statusMessage;
  String get mode => _mode;
  String? get savedCode => _savedCode;
  bool get hasConfig => _savedCode != null;
  String? get configError => _configError;

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
      final content = await file.readAsString();
      try {
        final doc = loadYaml(content);
        final groups = doc['proxy-groups'];
        if (groups is YamlList) {
          _groupOrder = groups
              .where((g) => g is YamlMap && g['name'] != null)
              .map<String>((g) => g['name'].toString())
              .toList();
          return;
        }
      } catch (_) {}
      // YAML 解析失败时降级：用正则提取顺序
      _groupOrder = _extractGroupNamesFallback(content)
          .map((g) => g.name)
          .toList();
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

    // ── 连接流程 ──────────────────────────────────────────────
    _setLoading(true, '正在连接...');
    final ok = await _mihomo.start();
    if (!ok) {
      _setLoading(false, '连接失败，请先导入订阅');
      return;
    }

    // 等待 mihomo REST API 就绪（最长 15s），每秒轮询一次
    bool apiReady = false;
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!await _mihomo.checkRunning()) break; // 进程已崩溃，提前退出
      if (await _mihomo.isApiReady()) { apiReady = true; break; }
    }

    if (!apiReady) {
      await _mihomo.stop();
      _setLoading(false, '连接失败，mihomo 未能启动');
      return;
    }

    // API 就绪 → 更新连接状态，放开按钮，后台继续加载节点
    _proxyEnabled = true;
    await _syncMode();
    _setLoading(false, '已连接 · 加载节点...');
    _startHealthCheck();
    _pollForNodes(); // 不 await，后台加载 proxy-providers 节点
  }

  /// 后台轮询节点（proxy-providers 需要联网拉取，可能需要 5~30s）。
  /// 每秒查一次 REST API，最多等 60s。
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
    // 超时：连接仍有效，但节点始终未出现（网络问题或配置无 proxy-providers）
    if (_proxyEnabled) {
      _statusMessage = '已连接';
      notifyListeners();
    }
  }

  /// 每 3 秒轮询 mihomo 进程是否存活，检测静默崩溃。
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

      final content = await file.readAsString();

      dynamic doc;
      try {
        doc = loadYaml(content);
      } catch (_) {
        // yaml 包对 YAML 流式序列中某些 emoji（变体选择符、国旗序列等）存在解析缺陷。
        // 降级为正则提取策略组名，成员列表留空，连接后由 REST API 填充。
        final groups = _extractGroupNamesFallback(content);
        if (groups.isNotEmpty) {
          _groups = {for (final g in groups) g.name: g};
          _groupOrder = groups.map((g) => g.name).toList();
          _configError = '连接后可查看完整节点列表';
          notifyListeners();
          return;
        }
        _configError = '配置文件包含无法解析的字符，请连接后查看节点';
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

      if (result.isEmpty) {
        _configError = '连接后可加载 proxy-providers 节点';
      }
      _groups = result;
      _groupOrder = order;
      notifyListeners();
    } catch (e) {
      _configError = '加载失败：$e';
      notifyListeners();
    }
  }

  /// YAML 解析失败时的降级方案：正则提取 proxy-groups 中的 name 字段。
  /// 只取组名和类型，成员列表留空（连接后由 REST API 填充）。
  List<ProxyGroup> _extractGroupNamesFallback(String content) {
    // 定位 proxy-groups: 块，截取到下一个根级 key 为止
    final start = content.indexOf('proxy-groups:');
    if (start == -1) return [];
    final section = content.substring(start);
    final nextRoot = RegExp(r'^\S', multiLine: true)
        .allMatches(section)
        .skip(1)
        .firstOrNull;
    final block = nextRoot != null ? section.substring(0, nextRoot.start) : section;

    // 匹配 name: <value>（支持引号和裸字符串，含 emoji）
    final nameRe = RegExp(r'''name:\s*['"]?([^'",}\n]+?)['"]?\s*[,}]''');
    final typeRe  = RegExp(r'''type:\s*['"]?(\w+)['"]?''');
    final groups  = <ProxyGroup>[];

    // 按行分组：每个 "- {" 或 "- name:" 开头为一个条目
    for (final entry in block.split(RegExp(r'^\s*-\s*', multiLine: true))) {
      final nameMatch = nameRe.firstMatch(entry);
      if (nameMatch == null) continue;
      final name = nameMatch.group(1)!.trim();
      if (name.isEmpty) continue;
      final type = typeRe.firstMatch(entry)?.group(1) ?? 'select';
      groups.add(ProxyGroup(name: name, type: type, current: '', members: []));
    }
    return groups;
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
