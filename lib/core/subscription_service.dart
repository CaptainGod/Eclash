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

  /// 只追加最小必要字段，避免破坏原始 YAML 结构
  String _patchConfig(String original) {
    final lines = <String>[];

    // external-controller：节点切换 REST API
    if (!original.contains('external-controller')) {
      lines.add('external-controller: "127.0.0.1:9090"');
    }

    // SOCKS5 端口：供 Android tun2socks 使用
    if (!original.contains('socks-port')) {
      lines.add('socks-port: 7891');
    }

    // HTTP 混合端口：供 Windows/macOS 系统代理使用
    if (!original.contains('mixed-port') && !original.contains('port:')) {
      lines.add('mixed-port: 7890');
    }

    if (lines.isEmpty) return original;
    return '$original\n${lines.join('\n')}\n';
  }

  Future<bool> configExists() async {
    final file = await getConfigFile();
    return file.existsSync();
  }
}
