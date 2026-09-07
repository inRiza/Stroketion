import 'package:shared_preferences/shared_preferences.dart';

class ApiHostStorage {
  ApiHostStorage._();

  static const _key = 'api_host_override';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> save(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, host.trim());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
