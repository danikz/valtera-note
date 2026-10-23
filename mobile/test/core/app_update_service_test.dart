import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/update/app_update_service.dart';

void main() {
  const apks = {
    'arm64-v8a': 'https://x/arm64.apk',
    'armeabi-v7a': 'https://x/v7a.apk',
    'x86_64': 'https://x/x86_64.apk',
  };

  test('memilih APK sesuai ABI utama perangkat', () {
    expect(AppUpdateService.pickApk(apks, ['arm64-v8a', 'armeabi-v7a']), 'https://x/arm64.apk');
    expect(AppUpdateService.pickApk(apks, ['armeabi-v7a', 'armeabi']), 'https://x/v7a.apk');
    expect(AppUpdateService.pickApk(apks, ['x86_64', 'arm64-v8a']), 'https://x/x86_64.apk');
  });

  test('ABI tidak dikenal jatuh ke arm64', () {
    expect(AppUpdateService.pickApk(apks, ['mips']), 'https://x/arm64.apk');
    expect(AppUpdateService.pickApk(const {}, ['arm64-v8a']), isNull);
  });
}
