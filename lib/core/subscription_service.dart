import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  // 固定前缀，替换为你的实际订阅服务器地址
  static const String _prefix = 'https://sub.example.com/sub/';
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
        final file = await getConfigFile();
        await file.writeAsString(response.body);
        await saveCode(code);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> configExists() async {
    final file = await getConfigFile();
    return file.existsSync();
  }
}
