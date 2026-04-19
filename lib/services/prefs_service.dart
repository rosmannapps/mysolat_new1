import 'package:mysolat/services/prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  PrefsService._();

  static SharedPreferences? _instance;

  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance {
    assert(_instance != null, 'Call PrefsService.init() in main() first');
    return _instance!;
  }
}