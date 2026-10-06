import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/core/theme/theme_controller.dart';
import 'package:valtera_note/features/auth/domain/models/auth_state.dart';
import 'package:valtera_note/features/auth/presentation/controllers/auth_controller.dart';
import 'package:valtera_note/features/settings/presentation/screens/settings_screen.dart';
import 'package:valtera_note/features/setup/data/repositories/setup_repository.dart';

class FakeSecureStorageService extends SecureStorageService {
  const FakeSecureStorageService();
}

class MockThemeController extends ThemeController {
  ThemeMode current = ThemeMode.dark;
  @override
  ThemeMode build() => current;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    current = mode;
    state = mode;
  }
}

class FakeSetupRepository extends SetupRepository {
  FakeSetupRepository() : super(storageService: const FakeSecureStorageService());
  @override
  Future<SupabaseConfigData> getConfig() async => const SupabaseConfigData();
}

class FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState();
}

void main() {
  testWidgets('SettingsScreen displays theme options', (tester) async {
    final mockTheme = MockThemeController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeControllerProvider.overrideWith(() => mockTheme),
          setupRepositoryProvider.overrideWithValue(FakeSetupRepository()),
          authControllerProvider.overrideWith(() => FakeAuthController()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    expect(find.text('TAMPILAN & TEMA'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Ikuti Sistem'), findsOneWidget);

    // Tap 'Terang'
    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();

    expect(mockTheme.current, equals(ThemeMode.light));
  });
}
