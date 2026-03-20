import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/proxy_node.dart';
import 'subscription_service.dart';

class MihomoService {
  static const String _apiBase = 'http://127.0.0.1:9090';
  static const String _secret = '';
  static const MethodChannel _vpnChannel =
      MethodChannel('com.captaingod.eclash/vpn');

  bool _running = false;
  bool get isRunning => _running;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_secret.isNotEmpty) 'Authorization': 'Bearer $_secret',
  };

  Future<bool> start() async {
    if (_running) return true;
    final configFile = await SubscriptionService().getConfigFile();
    if (!configFile.existsSync()) return false;
    final ok = await _vpnChannel.invokeMethod<bool>(
      'startVpn',
      {'configPath': configFile.path},
    );
    _running = ok ?? false;
    return _running;
  }

  Future<void> stop() async {
    try {
      await _vpnChannel.invokeMethod('stopVpn');
    } catch (_) {}
    _running = false;
  }

  /// mihomo 进程是否仍在运行（用于崩溃检测）。
  Future<bool> checkRunning() async {
    try {
      return await _vpnChannel.invokeMethod<bool>('isRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// mihomo REST API 是否已就绪（mihomo 启动需要数百毫秒，API 就绪才可操作）。
  Future<bool> isApiReady() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/version'), headers: _headers)
          .timeout(const Duration(seconds: 1));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, ProxyGroup>> getGroups() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/proxies'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body)['proxies'] as Map<String, dynamic>;
      final groups = <String, ProxyGroup>{};
      data.forEach((name, value) {
        if (value['type'] == 'Selector' || value['type'] == 'URLTest') {
          groups[name] = ProxyGroup.fromJson(name, value);
        }
      });
      return groups;
    } catch (_) {
      return {};
    }
  }

  Future<bool> selectNode(String group, String node) async {
    try {
      final res = await http.put(
        Uri.parse('$_apiBase/proxies/${Uri.encodeComponent(group)}'),
        headers: _headers,
        body: jsonEncode({'name': node}),
      );
      return res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<void> setMode(String mode) async {
    try {
      await http.patch(
        Uri.parse('$_apiBase/configs'),
        headers: _headers,
        body: jsonEncode({'mode': mode}),
      );
    } catch (_) {}
  }
}
