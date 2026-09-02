import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/data_refresh.dart';
import 'providers/settings_provider.dart';
import 'providers/shell_tabs.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_shell.dart';

/// Root widget: wires the providers, theme and the authentication gate.
class UniMateApp extends StatelessWidget {
  const UniMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => DataRefresh()),
        ChangeNotifierProvider(create: (_) => ShellTabs()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'UniMate',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            routes: {
              '/login': (_) => const LoginScreen(),
              '/signup': (_) => const SignupScreen(),
            },
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

/// Shows the app only to a signed-in user; everything else sees the login flow.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isRestoring) return const _SplashScreen();
    if (!auth.isAuthenticated) return const LoginScreen();

    // Rebuilding the shell per account keeps one user's state from leaking
    // into the next session on a shared device.
    return MainShell(key: ValueKey(auth.userId));
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.school, size: 36, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'UniMate',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
