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

  /// [codeOrUrl]：短码（自动拼前缀）或完整 http/https URL。
  Future<bool> downloadConfig(String codeOrUrl) async {
    final url = codeOrUrl.startsWith('http') ? codeOrUrl : '$_prefix$codeOrUrl';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final patched = _patchConfig(response.body);
        final file = await getConfigFile();
        await file.writeAsString(patched);
        await saveCode(codeOrUrl);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 向订阅配置追加运行所需的最小字段，不破坏原始 YAML 结构。
  /// tun: 段不在此注入——它在 VpnService 启动时携带实际 fd 动态写入。
  String _patchConfig(String original) {
    final lines = <String>[];

    // REST API：节点切换 / 模式切换
    if (!original.contains('external-controller')) {
      lines.add('external-controller: "127.0.0.1:9090"');
    }

    // DNS：TUN 模式必须启用，否则域名无法解析
    if (!original.contains('dns:')) {
      lines.addAll([
        'dns:',
        '  enable: true',
        '  enhanced-mode: fake-ip',
        '  nameserver:',
        '    - 8.8.8.8',
        '    - 1.1.1.1',
      ]);
    }

    if (lines.isEmpty) return original;
    return '$original\n${lines.join('\n')}\n';
  }

  Future<bool> configExists() async {
    final file = await getConfigFile();
    return file.existsSync();
  }
}
