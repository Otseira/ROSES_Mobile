import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'core/services/api_service.dart';
import 'core/services/branding_service.dart';

class SiroApp extends ConsumerWidget {
  const SiroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    // ✅ Loading saat cek token (app startup)
    if (authState.isLoading) {
      return const SplashLoading();
    }

    // ✅ Jika ada user → HomeScreen, jika tidak → LoginScreen
    return authState.user != null ? const HomeScreen() : const LoginScreen();
  }
}

class SplashLoading extends ConsumerStatefulWidget {
  const SplashLoading({super.key});
  @override
  ConsumerState<SplashLoading> createState() => _SplashLoadingState();
}

class _SplashLoadingState extends ConsumerState<SplashLoading> {
  BrandingData _b = const BrandingData();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) Cache dulu → tampil instan
    final c = await BrandingService.cached();
    if (!mounted) return;
    setState(() => _b = c);

    // 2) Refresh di latar → berlaku untuk pembukaan berikutnya
    final fresh = await BrandingService.refresh(ref.read(apiServiceProvider));
    if (!mounted) return;
    setState(() => _b = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = BrandingService.parseColor(_b.bgColor);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: warna admin → gambar admin → gradasi bawaan
          if (bgColor != null)
            ColoredBox(color: bgColor)
          else if (_b.bgUrl != null)
            Image.network(
              _b.bgUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _DefaultSplashBg(),
            )
          else
            const _DefaultSplashBg(),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SplashLogo(url: _b.logoUrl, size: 110),
                const SizedBox(height: 24),
                Text(
                  _b.nama ?? 'ROSES',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _b.tagline ?? 'Sistem Informasi Absensi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 44),
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
        ],
      ),
    );
  }
}

class _DefaultSplashBg extends StatelessWidget {
  const _DefaultSplashBg();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F5E9), Color(0xFFF5F7F5), Colors.white],
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  final String? url;
  final double size;
  const _SplashLogo({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(Icons.fingerprint, color: Colors.white, size: size * 0.5),
    );

    if (url == null) return fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.network(
          url!,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
