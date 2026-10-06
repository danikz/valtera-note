import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/core/theme/theme_controller.dart';
import 'package:valtera_note/features/setup/data/repositories/setup_repository.dart';

class FakeSecureStorageService extends SecureStorageService {
  String? storedTheme;
  @override
  Future<void> saveThemeMode(String mode) async {
    storedTheme = mode;
  }
  @override
  Future<String?> getThemeMode() async {
    return storedTheme;
  }
}

void main() {
  test('ThemeController defaults to ThemeMode.dark', () {
    final fakeStorage = FakeSecureStorageService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final theme = container.read(themeControllerProvider);
    expect(theme, equals(ThemeMode.dark));
  });

  test('setThemeMode updates state and persists choice', () async {
    final fakeStorage = FakeSecureStorageService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(themeControllerProvider.notifier);
    await controller.setThemeMode(ThemeMode.light);

    expect(container.read(themeControllerProvider), equals(ThemeMode.light));
    expect(fakeStorage.storedTheme, equals('light'));
  });

  test('toggleTheme switches between dark and light', () async {
    final fakeStorage = FakeSecureStorageService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(themeControllerProvider.notifier);
    await controller.toggleTheme(true); // currently dark -> should switch to light
    expect(container.read(themeControllerProvider), equals(ThemeMode.light));

    await controller.toggleTheme(false); // currently light -> should switch to dark
    expect(container.read(themeControllerProvider), equals(ThemeMode.dark));
  });
}
