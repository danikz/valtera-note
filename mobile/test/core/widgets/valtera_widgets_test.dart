import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/theme/app_colors.dart';
import 'package:valtera_note/core/widgets/valtera_button.dart';
import 'package:valtera_note/core/widgets/valtera_text_field.dart';
import 'package:valtera_note/core/widgets/status_indicator.dart';
import 'package:valtera_note/core/widgets/offline_banner.dart';

void main() {
  group('ValteraButton Tests', () {
    testWidgets('renders text and minimum touch target size 48dp', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValteraButton(
              text: 'Simpan Catatan',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Simpan Catatan'), findsOneWidget);
      final size = tester.getSize(find.byType(ValteraButton));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.byType(ValteraButton));
      expect(pressed, isTrue);
    });

    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValteraButton(
              text: 'Simpan',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);
    });
  });

  group('ValteraTextField Tests', () {
    testWidgets('renders label, hint and responds to user input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValteraTextField(
              controller: controller,
              label: 'Project URL',
              hintText: 'https://xyz.supabase.co',
            ),
          ),
        ),
      );

      expect(find.text('Project URL'), findsOneWidget);
      expect(find.text('https://xyz.supabase.co'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'https://test.supabase.co');
      expect(controller.text, 'https://test.supabase.co');
    });

    testWidgets('displays error text when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValteraTextField(
              label: 'Email',
              errorText: 'Format email tidak valid',
            ),
          ),
        ),
      );

      expect(find.text('Format email tidak valid'), findsOneWidget);
    });
  });

  group('StatusIndicator Tests', () {
    testWidgets('renders correct text and status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusIndicator(status: SyncDisplayStatus.synced),
                StatusIndicator(status: SyncDisplayStatus.local),
                StatusIndicator(status: SyncDisplayStatus.syncing),
                StatusIndicator(status: SyncDisplayStatus.error),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });
  });

  group('OfflineBanner Tests', () {
    testWidgets('renders offline banner with descriptive text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(message: 'Mode Offline — Disimpan di perangkat'),
          ),
        ),
      );

      expect(find.text('Mode Offline — Disimpan di perangkat'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });

  group('AppColors Semantic Tokens Tests', () {
    test('verifies primary and dark background tokens', () {
      expect(AppColors.primary, const Color(0xFF0D9488));
      expect(AppColors.darkBackground, const Color(0xFF020617));
      expect(AppColors.darkSurface, const Color(0xFF0F172A));
      expect(AppColors.emeraldAccent, const Color(0xFF10B981));
    });
  });
}
