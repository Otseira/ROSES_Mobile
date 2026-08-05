import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../../core/widgets/instansi_branding.dart';
import '../../../core/services/storage_service.dart'; // ✅ untuk footer dinamis

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // ✅ Nama instansi untuk footer (default dulu, diperbarui dari cache)
  String _footerInstansi = 'RSKB Ropanasuri';

  @override
  void initState() {
    super.initState();
    _loadFooterInstansi(); // baca nama instansi dari cache (ditulis oleh InstansiBranding)
  }

  Future<void> _loadFooterInstansi() async {
    final nama = await StorageService.read('branding_nama');
    if (!mounted) return;
    if (nama != null && nama.trim().isNotEmpty) {
      setState(() => _footerInstansi = nama.trim());
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .login(_loginController.text.trim(), _passwordController.text);

    if (success && mounted) {
      // Paksa provider profil memuat ulang data user dengan token baru,
      // supaya Home/Profil langsung menampilkan nama & unit kerja.
      ref.invalidate(authStateProvider);
      try {
        await ref.read(authStateProvider.future);
      } catch (_) {
        // bila /me gagal sesaat, tetap lanjut (tidak menghalangi masuk)
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: size.height * 0.06),

                // ✅ LOGO + NAMA INSTANSI DINAMIS (mengikuti Pengaturan Sistem)
                //    Otomatis jatuh ke logo bawaan + nama default bila server
                //    lambat / gagal / belum diatur — login tak pernah kosong.
                const Center(child: InstansiBranding(logoSize: 96)),

                const SizedBox(height: 8),

                // Sapaan (headline). Hapus blok ini bila ingin nama instansi
                // dari widget menjadi satu-satunya judul.
                const Text(
                  'Selamat Datang',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masuk untuk melanjutkan absensi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textHint),
                ),

                const SizedBox(height: 40),

                // Username / NIK
                TextFormField(
                  controller: _loginController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username / NIK',
                    hintText: 'Masukkan username atau NIK',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),

                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Masukkan password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),

                const SizedBox(height: 32),

                // Error
                if (authState.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Login Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Masuk'),
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ Footer dinamis (nama instansi ikut cache branding)
                Text(
                  'SIRO v1.0.0 • $_footerInstansi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),

                const SizedBox(height: 8),

                // ✅ COPYRIGHT
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copyright,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${DateTime.now().year} Luthfi Ariesto Prayoga & Teddi Takejo Saogok',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'IT RSKB ROPANASURI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: size.height * 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
