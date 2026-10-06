import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/features/setup/data/repositories/setup_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService storageService;
  late SetupRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storageService = SecureStorageService(storage: const FlutterSecureStorage());
    repo = SetupRepository(
      storageService: storageService,
      httpClient: http.Client(),
    );
  });

  group('SetupRepository Validation Tests', () {
    test('validates empty URL', () {
      final error = repo.validateUrl('');
      expect(error, 'Supabase URL wajib diisi');
    });

    test('validates non-https URL', () {
      final error = repo.validateUrl('http://test.supabase.co');
      expect(error, 'URL harus menggunakan HTTPS');
    });

    test('validates invalid domain format', () {
      final error = repo.validateUrl('https://not-a-domain');
      expect(error, 'Format URL Supabase tidak valid');
    });

    test('accepts valid https URL', () {
      final error = repo.validateUrl('https://xyzcompany.supabase.co');
      expect(error, isNull);
    });

    test('validates empty anon key', () {
      final error = repo.validateAnonKey('');
      expect(error, 'Anon key wajib diisi');
    });

    test('rejects service role key if identified', () {
      final error = repo.validateAnonKey('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5eiIsInJvbGUiOiJzZXJ2aWNlX3JvbGUifQ.signature');
      expect(error, contains('Service Role Key tidak boleh digunakan'));
    });
  });

  group('SetupRepository Connection Tests', () {
    test('testConnection returns success when endpoint responds 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/v1/health')) {
          return http.Response('{"version": "1.0"}', 200);
        }
        if (request.url.path.contains('/rest/v1/notes')) {
          return http.Response('[]', 200);
        }
        return http.Response('Not Found', 404);
      });

      final testRepo = SetupRepository(
        storageService: storageService,
        httpClient: mockClient,
      );

      final result = await testRepo.testConnection(
        url: 'https://test.supabase.co',
        anonKey: 'sample-anon-key',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isTableReady, isTrue);
      expect(result.message, contains('berhasil terhubung'));
    });

    test('testConnection reports table missing when 404 / 42P01 is returned', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/v1/health')) {
          return http.Response('{"version": "1.0"}', 200);
        }
        if (request.url.path.contains('/rest/v1/notes')) {
          return http.Response('{"message": "relation public.notes does not exist", "code": "42P01"}', 404);
        }
        return http.Response('Not Found', 404);
      });

      final testRepo = SetupRepository(
        storageService: storageService,
        httpClient: mockClient,
      );

      final result = await testRepo.testConnection(
        url: 'https://test.supabase.co',
        anonKey: 'sample-anon-key',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isTableReady, isFalse);
      expect(result.message, contains("Tabel 'notes' belum dibuat"));
    });
  });
}
