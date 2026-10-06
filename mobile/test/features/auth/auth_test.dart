import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/features/auth/data/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storageService;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storageService = SecureStorageService(storage: const FlutterSecureStorage());
    await storageService.saveSupabaseConfig(
      url: 'https://test.supabase.co',
      anonKey: 'sample-anon-key',
    );
  });

  group('AuthRepository Tests', () {
    test('login success saves tokens and user email', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/v1/token') &&
            request.url.queryParameters['grant_type'] == 'password') {
          return http.Response(
            jsonEncode({
              'access_token': 'test-access-token',
              'refresh_token': 'test-refresh-token',
              'expires_in': 3600,
              'user': {
                'id': 'user-uuid-1234',
                'email': 'user@valtera.id',
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final authRepo = AuthRepository(
        storageService: storageService,
        httpClient: mockClient,
      );

      final result = await authRepo.login(
        email: 'user@valtera.id',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.email, 'user@valtera.id');

      final session = await storageService.getAuthSession();
      expect(session.accessToken, 'test-access-token');
      expect(session.refreshToken, 'test-refresh-token');
      expect(session.userEmail, 'user@valtera.id');
      expect(session.isLoggedIn, isTrue);
    });

    test('login failure returns clean error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error_description': 'Invalid login credentials',
            'msg': 'Invalid login credentials',
          }),
          400,
        );
      });

      final authRepo = AuthRepository(
        storageService: storageService,
        httpClient: mockClient,
      );

      final result = await authRepo.login(
        email: 'wrong@valtera.id',
        password: 'wrongpassword',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Invalid login credentials'));
    });

    test('register success handles email confirmation', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/v1/signup')) {
          return http.Response(
            jsonEncode({
              'id': 'new-user-123',
              'email': 'new@valtera.id',
              'confirmation_sent_at': '2026-10-05T12:00:00Z',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final authRepo = AuthRepository(
        storageService: storageService,
        httpClient: mockClient,
      );

      final result = await authRepo.register(
        email: 'new@valtera.id',
        password: 'securepassword',
      );

      expect(result.isSuccess, isTrue);
      expect(result.email, 'new@valtera.id');
    });

    test('logout clears auth session', () async {
      await storageService.saveAuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userEmail: 'user@valtera.id',
      );

      final authRepo = AuthRepository(
        storageService: storageService,
        httpClient: http.Client(),
      );

      await authRepo.logout();

      final session = await storageService.getAuthSession();
      expect(session.isLoggedIn, isFalse);
      expect(session.accessToken, isNull);
    });
  });
}
