import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

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
        // 强制 UTF-8 解码：Dart http 包在服务器未声明 charset 时对 text/* 默认使用
        // ISO-8859-1，会把多字节 UTF-8 序列（中文、emoji）逐字节拆散成乱码。
        final patched = _patchConfig(utf8.decode(response.bodyBytes));
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

  /// 从配置的 proxy-providers 直接下载节点名称列表（走直连，App 流量已绕过 VPN）。
  /// [configDoc]：已解析的 YAML 文档。
  /// 返回所有提供商的代理节点名，供离线预填策略组使用。
  Future<List<String>> fetchProviderProxyNames(dynamic configDoc) async {
    final names = <String>[];

    // 内联 proxies（直接写在配置里的节点）
    final inline = configDoc['proxies'];
    if (inline is YamlList) {
      for (final p in inline) {
        if (p is YamlMap) {
          final n = p['name']?.toString();
          if (n != null && n.isNotEmpty) names.add(n);
        }
      }
    }

    // proxy-providers（机场订阅 URL）
    final providers = configDoc['proxy-providers'];
    if (providers is YamlMap) {
      for (final prov in providers.values) {
        if (prov is! YamlMap) continue;
        final url = prov['url']?.toString();
        if (url == null || !url.startsWith('http')) continue;
        try {
          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (res.statusCode != 200) continue;
          final doc = loadYaml(utf8.decode(res.bodyBytes));
          final proxies = doc['proxies'];
          if (proxies is YamlList) {
            for (final p in proxies) {
              if (p is YamlMap) {
                final n = p['name']?.toString();
                if (n != null && n.isNotEmpty) names.add(n);
              }
            }
          }
        } catch (_) {}
      }
    }

    return names;
  }

  /// 向订阅配置追加运行所需的最小字段，不破坏原始 YAML 结构。
  String _patchConfig(String original) {
    final lines = <String>[];

    if (!original.contains('external-controller')) {
      lines.add('external-controller: "127.0.0.1:9090"');
    }

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
