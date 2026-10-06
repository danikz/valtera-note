import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/presentation/screens/notes_list_screen.dart';
import '../../features/notes/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/setup/data/repositories/setup_repository.dart';
import '../../features/setup/presentation/controllers/setup_controller.dart';
import '../../features/setup/presentation/screens/setup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final setupState = ref.watch(setupControllerProvider);

  return GoRouter(
    initialLocation: '/notes',
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              return NoteEditorScreen(noteId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) async {
      final repo = ref.read(setupRepositoryProvider);
      final config = await repo.getConfig();

      final isConfigured = config.isConfigured || setupState.isConfigured;
      final goingToSetup = state.matchedLocation == '/setup';

      if (!isConfigured && !goingToSetup) {
        return '/setup';
      }

      return null;
    },
  );
});
