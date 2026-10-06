import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/setup/data/repositories/setup_repository.dart';
import '../storage/secure_storage_service.dart';

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

class ThemeController extends Notifier<ThemeMode> {
  late final SecureStorageService _storage;

  @override
  ThemeMode build() {
    _storage = ref.watch(secureStorageServiceProvider);
    _loadThemeFromStorage();
    return ThemeMode.dark;
  }

  Future<void> _loadThemeFromStorage() async {
    final modeStr = await _storage.getThemeMode();
    if (modeStr != null) {
      switch (modeStr) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    await _storage.saveThemeMode(modeStr);
  }

  Future<void> toggleTheme(bool isCurrentlyDark) async {
    if (isCurrentlyDark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
