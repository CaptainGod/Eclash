import 'package:flutter/material.dart';
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
  String? _savedCode;

  bool get proxyEnabled => _proxyEnabled;
  bool get loading => _loading;
  String get statusMessage => _statusMessage;
  Map<String, ProxyGroup> get groups => _groups;
  String? get savedCode => _savedCode;

  Future<void> init() async {
    _savedCode = await _sub.getSavedCode();
    notifyListeners();
  }

  Future<bool> downloadSubscription(String code) async {
    _setLoading(true, '正在下载配置...');
    final ok = await _sub.downloadConfig(code);
    _savedCode = ok ? code : _savedCode;
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
      _setLoading(false, '已断开');
    } else {
      _setLoading(true, '正在连接...');
      final ok = await _mihomo.start();
      if (ok) {
        _proxyEnabled = true;
        await refreshGroups();
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

  void _setLoading(bool value, String message) {
    _loading = value;
    _statusMessage = message;
    notifyListeners();
  }
}
