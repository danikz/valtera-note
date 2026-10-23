import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Manifest rilis Android di bucket Cloudflare R2 yang sama dengan updater
/// desktop — diunggah CI setiap rilis (lihat job build-android).
const androidUpdateManifestUrl = 'https://valtera-note-update.valtera.id/android/latest.json';

class AppUpdateInfo {
  final String currentVersion;
  final String version;
  final int build;
  final String notes;
  final String apkUrl;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.version,
    required this.build,
    required this.notes,
    required this.apkUrl,
  });
}

final packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) => AppUpdateService());

/// Cek sekali saat app dibuka; gagal (offline dll) = diam saja.
final startupUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  try {
    return await ref.read(appUpdateServiceProvider).check();
  } catch (_) {
    return null;
  }
});

class AppUpdateService {
  final http.Client _client;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// null = sudah versi terbaru (atau bukan Android).
  Future<AppUpdateInfo?> check() async {
    if (!Platform.isAndroid) return null;

    final res = await _client
        .get(Uri.parse(androidUpdateManifestUrl), headers: {'Cache-Control': 'no-cache'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Gagal mengecek pembaruan (HTTP ${res.statusCode})');
    }
    final manifest = jsonDecode(res.body) as Map<String, dynamic>;

    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final latestBuild = (manifest['build'] as num?)?.toInt() ?? 0;
    if (latestBuild <= currentBuild) return null;

    final apks = (manifest['apks'] as Map?)?.cast<String, dynamic>() ?? {};
    final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
    final url = pickApk(apks, abis);
    if (url == null) return null;

    return AppUpdateInfo(
      currentVersion: info.version,
      version: (manifest['version'] as String?) ?? '?',
      build: latestBuild,
      notes: (manifest['notes'] as String?)?.trim() ?? '',
      apkUrl: url,
    );
  }

  /// APK split-per-abi yang cocok dengan HP — urutan [supportedAbis] dari
  /// yang paling disukai perangkat.
  static String? pickApk(Map<String, dynamic> apks, List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      final url = apks[abi];
      if (url is String && url.isNotEmpty) return url;
    }
    final fallback = apks['arm64-v8a'] ?? apks['armeabi-v7a'];
    return fallback is String ? fallback : null;
  }
}

/// Dialog "Update tersedia" — APK diunduh lewat browser / download manager,
/// lalu Android menampilkan layar pasang seperti biasa.
Future<void> showAppUpdateDialog(BuildContext context, AppUpdateInfo info) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = isDark ? AppColors.emeraldAccent : AppColors.primary;
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: accent),
          const SizedBox(width: 10),
          Text(
            'Update tersedia',
            style: AppTypography.headingSmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versi ${info.version} sudah rilis (terpasang: ${info.currentVersion}).',
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  info.notes,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nanti')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: isDark ? Colors.black : Colors.white,
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Unduh & Pasang'),
          onPressed: () async {
            Navigator.pop(ctx);
            await launchUrl(Uri.parse(info.apkUrl), mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
  );
}
