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

  Process? _process;
  bool _running = false;

  bool get isRunning => _running;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_secret.isNotEmpty) 'Authorization': 'Bearer $_secret',
  };

  Future<String> _getMihomoBinaryPath() async {
    final dir = await getApplicationSupportDirectory();
    final ext = Platform.isWindows ? '.exe' : '';
    final dest = File('${dir.path}/mihomo$ext');

    if (!dest.existsSync()) {
      // 从 assets 复制到可执行目录
      final bytes = await rootBundle.load('assets/mihomo/mihomo$ext');
      await dest.writeAsBytes(bytes.buffer.asUint8List());
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', dest.path]);
      }
    }
    return dest.path;
  }

  Future<bool> start() async {
    if (_running) return true;

    final sub = SubscriptionService();
    final configFile = await sub.getConfigFile();
    if (!configFile.existsSync()) return false;

    try {
      final binaryPath = await _getMihomoBinaryPath();
      _process = await Process.start(binaryPath, ['-f', configFile.path]);
      await Future.delayed(const Duration(milliseconds: 800));
      _running = true;
      await _enableSystemProxy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    await _disableSystemProxy();
    _process?.kill();
    _process = null;
    _running = false;
  }

  Future<Map<String, ProxyGroup>> getGroups() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/proxies'),
        headers: _headers,
      );
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

  Future<void> _enableSystemProxy() async {
    if (Platform.isMacOS) {
      await Process.run('networksetup', ['-setwebproxy', 'Wi-Fi', '127.0.0.1', '7890']);
      await Process.run('networksetup', ['-setsecurewebproxy', 'Wi-Fi', '127.0.0.1', '7890']);
    } else if (Platform.isWindows) {
      await Process.run('reg', [
        'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f'
      ]);
      await Process.run('reg', [
        'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '127.0.0.1:7890', '/f'
      ]);
    }
  }

  Future<void> _disableSystemProxy() async {
    if (Platform.isMacOS) {
      await Process.run('networksetup', ['-setwebproxystate', 'Wi-Fi', 'off']);
      await Process.run('networksetup', ['-setsecurewebproxystate', 'Wi-Fi', 'off']);
    } else if (Platform.isWindows) {
      await Process.run('reg', [
        'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f'
      ]);
    }
  }
}
