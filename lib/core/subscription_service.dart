import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String _prefix = 'https://1814840116.v.123pan.cn/1814840116/';
  static const String _prefKey = 'subscription_code';

  Future<String?> getSavedCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  Future<void> saveCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  Future<File> getConfigFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/config.yaml');
  }

  Future<bool> downloadConfig(String code) async {
    final url = '$_prefix$code';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final patched = _patchConfig(response.body);
        final file = await getConfigFile();
        await file.writeAsString(patched);
        await saveCode(code);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _patchConfig(String yaml) {
    var result = yaml;

    // REST API（节点切换必须）
    if (!result.contains('external-controller')) {
      result += '\nexternal-controller: 127.0.0.1:9090\n';
    }

    // 混合端口（Windows/macOS 系统代理）
    if (!result.contains('mixed-port') && !result.contains('port:')) {
      result += 'mixed-port: 7890\n';
    }

    // Android TUN 模式配置（mihomo 将接管路由）
    if (!result.contains('tun:') && Platform.isAndroid) {
      result += '''
tun:
  enable: true
  stack: system
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - any:53
''';
    }

    // DNS（确保解析正常）
    if (!result.contains('dns:')) {
      result += '''
dns:
  enable: true
  listen: 0.0.0.0:53
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
''';
    }

    return result;
  }

  Future<bool> configExists() async {
    final file = await getConfigFile();
    return file.existsSync();
  }
}
