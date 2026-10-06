import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/setup/presentation/screens/setup_screen.dart';

void main() {
  testWidgets('SetupScreen renders input fields and action buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SetupScreen(),
        ),
      ),
    );

    expect(find.text('Hubungkan Supabase'), findsOneWidget);
    expect(find.text('Project URL'), findsOneWidget);
    expect(find.text('Anon Public Key'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
    expect(find.text('Simpan & Lanjutkan'), findsOneWidget);
  });
}
