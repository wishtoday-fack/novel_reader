import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  final SharedPreferences _prefs;
  
  SettingsRepository(this._prefs);

  // Font settings
  double get fontSize => _prefs.getDouble('font_size') ?? 18.0;
  Future<void> setFontSize(double v) => _prefs.setDouble('font_size', v);
  
  double get lineSpacing => _prefs.getDouble('line_spacing') ?? 1.5;
  Future<void> setLineSpacing(double v) => _prefs.setDouble('line_spacing', v);
  
  // Theme settings
  int get themeIndex => _prefs.getInt('theme_index') ?? 0;
  Future<void> setThemeIndex(int v) => _prefs.setInt('theme_index', v);
  
  // Reading settings
  bool get autoSaveProgress => _prefs.getBool('auto_save_progress') ?? true;
  Future<void> setAutoSaveProgress(bool v) => _prefs.setBool('auto_save_progress', v);
  
  int get pageAnimationMode => _prefs.getInt('page_animation_mode') ?? 0;
  Future<void> setPageAnimationMode(int v) => _prefs.setInt('page_animation_mode', v);
  
  // Brightness
  double get brightness => _prefs.getDouble('brightness') ?? 1.0;
  Future<void> setBrightness(double v) => _prefs.setDouble('brightness', v);
  
  // Keep screen on
  bool get keepScreenOn => _prefs.getBool('keep_screen_on') ?? true;
  Future<void> setKeepScreenOn(bool v) => _prefs.setBool('keep_screen_on', v);
}
