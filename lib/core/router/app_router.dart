import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../config/config_store.dart';
import '../../features/gateway/screens/gateway_screen.dart';
import '../../features/setup/screens/setup_wizard_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/faculty/screens/faculty_dashboard.dart';
import '../../features/student/screens/student_dashboard.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState routerState) {
    final authState = _ref.read(authProvider);
    final configReady = ConfigStore.instance.isReady;
    final isAuthenticated = authState.isAuthenticated;
    final isLoading = authState.isLoading;
    final path = routerState.uri.path;

    if (isLoading) return null;

    if (!configReady && path != '/' && path != '/setup') return '/';

    if (configReady && !isAuthenticated && path == '/') return '/login';

    const publicPaths = ['/', '/setup', '/login'];
    if (!isAuthenticated && !publicPaths.contains(path)) return '/login';

    if (isAuthenticated && (path == '/' || path == '/login')) {
      return _roleHome(authState.user!.role);
    }

    if (isAuthenticated) {
      final role = authState.user!.role;
      final correctHome = _roleHome(role);
      const dashboards = ['/admin', '/faculty', '/student'];
      final onDashboard = dashboards.any((d) => path.startsWith(d));
      if (onDashboard && !path.startsWith(correctHome)) {
        return correctHome;
      }
    }

    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const GatewayScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupWizardScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShell(),
        routes: [
          GoRoute(
            path: 'upload',
            builder: (_, __) => const AdminShell(initialSection: 'upload'),
          ),
        ],
      ),
      GoRoute(path: '/faculty', builder: (_, __) => const FacultyDashboard()),
      GoRoute(path: '/student', builder: (_, __) => const StudentDashboard()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

String _roleHome(String role) {
  switch (role) {
    case 'super_admin':
    case 'admin':
      return '/admin';
    case 'faculty':
      return '/faculty';
    default:
      return '/student';
  }
}
