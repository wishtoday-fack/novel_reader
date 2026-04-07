import 'package:flutter/material.dart';
import 'package:novel_reader/repositories/settings_repository.dart';
import 'package:novel_reader/utils/themes.dart' show ReaderTheme;

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;
  
  double _fontSize;
  double _lineSpacing;
  int _themeIndex;
  bool _autoSaveProgress;
  int _pageAnimationMode;
  double _brightness;
  bool _keepScreenOn;

  SettingsProvider(this._repo)
      : _fontSize = _repo.fontSize, 
        _lineSpacing = _repo.lineSpacing, 
        _themeIndex = _repo.themeIndex,
        _autoSaveProgress = _repo.autoSaveProgress,
        _pageAnimationMode = _repo.pageAnimationMode,
        _brightness = _repo.brightness,
        _keepScreenOn = _repo.keepScreenOn;

  // Getters
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  int get themeIndex => _themeIndex;
  ReaderTheme get theme => ReaderTheme.presets[_themeIndex.clamp(0, ReaderTheme.presets.length - 1)];
  bool get autoSaveProgress => _autoSaveProgress;
  int get pageAnimationMode => _pageAnimationMode;
  double get brightness => _brightness;
  bool get keepScreenOn => _keepScreenOn;

  // Setters
  Future<void> setFontSize(double v) async { 
    _fontSize = v; 
    await _repo.setFontSize(v); 
    notifyListeners(); 
  }
  
  Future<void> setLineSpacing(double v) async { 
    _lineSpacing = v; 
    await _repo.setLineSpacing(v); 
    notifyListeners(); 
  }
  
  Future<void> setThemeIndex(int v) async { 
    _themeIndex = v.clamp(0, ReaderTheme.presets.length - 1);
    await _repo.setThemeIndex(_themeIndex); 
    notifyListeners(); 
  }
  
  Future<void> setAutoSaveProgress(bool v) async {
    _autoSaveProgress = v;
    await _repo.setAutoSaveProgress(v);
    notifyListeners();
  }
  
  Future<void> setPageAnimationMode(int v) async {
    _pageAnimationMode = v;
    await _repo.setPageAnimationMode(v);
    notifyListeners();
  }
  
  Future<void> setBrightness(double v) async {
    _brightness = v.clamp(0.1, 1.0);
    await _repo.setBrightness(_brightness);
    notifyListeners();
  }
  
  Future<void> setKeepScreenOn(bool v) async {
    _keepScreenOn = v;
    await _repo.setKeepScreenOn(v);
    notifyListeners();
  }
  
  // Navigation
  void nextTheme() {
    final next = (_themeIndex + 1) % ReaderTheme.presets.length;
    setThemeIndex(next);
  }
  
  void previousTheme() {
    final prev = (_themeIndex - 1 + ReaderTheme.presets.length) % ReaderTheme.presets.length;
    setThemeIndex(prev);
  }
}
