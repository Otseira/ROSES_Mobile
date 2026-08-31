import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';

class SiroApp extends ConsumerWidget {
  const SiroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Gunakan authNotifierProvider (StateNotifier) agar reaktif ke perubahan logout/login
    final authState = ref.watch(authNotifierProvider);

    return MaterialApp(
      title: 'ROSES',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _buildHome(authState),
      routes: AppRoutes.routes,
    );
  }

  Widget _buildHome(AuthState authState) {
    if (authState.isLoading) {
      return const SplashLoading();
    }

    // Jika ada user di state → tampilkan Home, jika tidak → Login
    return authState.user != null ? const HomeScreen() : const LoginScreen();
  }
}

class SplashLoading extends StatelessWidget {
  const SplashLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ROSES',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sistem Informasi Absensi',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
