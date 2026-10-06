import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storageService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storageService = SecureStorageService(storage: const FlutterSecureStorage());
  });

  group('SecureStorageService Tests', () {
    test('save and retrieve Supabase config', () async {
      await storageService.saveSupabaseConfig(
        url: 'https://xyzcompany.supabase.co',
        anonKey: 'sample-anon-key-12345',
      );

      final config = await storageService.getSupabaseConfig();
      expect(config.url, 'https://xyzcompany.supabase.co');
      expect(config.anonKey, 'sample-anon-key-12345');
      expect(config.isConfigured, isTrue);
    });

    test('clear Supabase config removes saved values and auth session', () async {
      await storageService.saveSupabaseConfig(
        url: 'https://xyzcompany.supabase.co',
        anonKey: 'sample-anon-key-12345',
      );
      await storageService.saveAuthSession(
        accessToken: 'access-jwt-token',
        refreshToken: 'refresh-jwt-token',
        userEmail: 'user@valtera.id',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await storageService.clearSupabaseConfig();

      final config = await storageService.getSupabaseConfig();
      expect(config.url, isNull);
      expect(config.anonKey, isNull);
      expect(config.isConfigured, isFalse);

      final session = await storageService.getAuthSession();
      expect(session.accessToken, isNull);
      expect(session.isLoggedIn, isFalse);
    });

    test('save and retrieve auth session', () async {
      final expiry = DateTime.utc(2026, 10, 6, 12, 0, 0);
      await storageService.saveAuthSession(
        accessToken: 'access-token-abc',
        refreshToken: 'refresh-token-xyz',
        userEmail: 'admin@valtera.id',
        expiresAt: expiry,
      );

      final session = await storageService.getAuthSession();
      expect(session.accessToken, 'access-token-abc');
      expect(session.refreshToken, 'refresh-token-xyz');
      expect(session.userEmail, 'admin@valtera.id');
      expect(session.expiresAt, expiry);
      expect(session.isLoggedIn, isTrue);
    });

    test('clearAuthSession only clears tokens and user email', () async {
      await storageService.saveSupabaseConfig(
        url: 'https://xyzcompany.supabase.co',
        anonKey: 'sample-anon-key-12345',
      );
      await storageService.saveAuthSession(
        accessToken: 'access-token-abc',
        refreshToken: 'refresh-token-xyz',
        userEmail: 'admin@valtera.id',
      );

      await storageService.clearAuthSession();

      final session = await storageService.getAuthSession();
      expect(session.accessToken, isNull);
      expect(session.isLoggedIn, isFalse);

      // Supabase config must still be intact
      final config = await storageService.getSupabaseConfig();
      expect(config.url, 'https://xyzcompany.supabase.co');
    });
  });
}
