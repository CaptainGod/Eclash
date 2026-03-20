import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/proxy_node.dart';
import 'subscription_service.dart';

class MihomoService {
  static const String _apiBase = 'http://127.0.0.1:9090';
  static const String _secret = '';
  static const MethodChannel _vpnChannel =
      MethodChannel('com.captaingod.eclash/vpn');

  Process? _process;
  bool _running = false;

  bool get isRunning => _running;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_secret.isNotEmpty) 'Authorization': 'Bearer $_secret',
  };

  Future<bool> start() async {
    if (_running) return true;

    final sub = SubscriptionService();
    final configFile = await sub.getConfigFile();
    if (!configFile.existsSync()) return false;

    try {
      if (Platform.isAndroid) {
        // Android：通过 MethodChannel 调用原生 VpnService
        final ok = await _vpnChannel.invokeMethod<bool>(
          'startVpn',
          {'configPath': configFile.path},
        );
        _running = ok ?? false;
      } else {
        // Windows / macOS：子进程模式
        final binaryPath = await _getMihomoBinaryPath();
        _process = await Process.start(binaryPath, ['-f', configFile.path]);
        await Future.delayed(const Duration(milliseconds: 800));
        _running = true;
        await _enableSystemProxy();
      }
      return _running;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      if (Platform.isAndroid) {
        await _vpnChannel.invokeMethod('stopVpn');
      } else {
        await _disableSystemProxy();
        _process?.kill();
        _process = null;
      }
    } catch (_) {}
    _running = false;
  }

  Future<String> _getMihomoBinaryPath() async {
    final dir = await getApplicationSupportDirectory();
    final ext = Platform.isWindows ? '.exe' : '';
    final dest = File('${dir.path}/mihomo$ext');

    if (!dest.existsSync()) {
      final bytes = await rootBundle.load('assets/mihomo/mihomo$ext');
      await dest.writeAsBytes(bytes.buffer.asUint8List());
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', dest.path]);
      }
    }
    return dest.path;
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

  Future<void> _enableSystemProxy() async {
    if (Platform.isMacOS) {
      await Process.run('networksetup',
          ['-setwebproxy', 'Wi-Fi', '127.0.0.1', '7890']);
      await Process.run('networksetup',
          ['-setsecurewebproxy', 'Wi-Fi', '127.0.0.1', '7890']);
    } else if (Platform.isWindows) {
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f'
      ]);
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '127.0.0.1:7890', '/f'
      ]);
    }
  }

  Future<void> _disableSystemProxy() async {
    if (Platform.isMacOS) {
      await Process.run(
          'networksetup', ['-setwebproxystate', 'Wi-Fi', 'off']);
      await Process.run(
          'networksetup', ['-setsecurewebproxystate', 'Wi-Fi', 'off']);
    } else if (Platform.isWindows) {
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f'
      ]);
    }
  }
}
