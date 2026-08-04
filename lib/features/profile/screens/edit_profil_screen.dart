import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfilScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const EditProfilScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends ConsumerState<EditProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();

  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _loading = false;
  bool _loadingPassword = false;
  bool _loadingFoto = false;
  bool _showCurrentPass = true;
  bool _showNewPass = true;

  String? _fotoUrl;

  @override
  void initState() {
    super.initState();
    _namaController.text = widget.user.nama;
    _usernameController.text = widget.user.username;
    _emailController.text = widget.user.email ?? '';
    _whatsappController.text = widget.user.nomorWhatsapp ?? '';
    _fotoUrl = widget.user.fotoProfil;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  // ============ UPDATE FOTO PROFIL (DARI GALERI) ============
  Future<void> _ubahFoto() async {
    setState(() => _loadingFoto = true);

    try {
      final picker = ImagePicker();

      // Buka galeri; kompres otomatis agar upload cepat (maks 1024px, kualitas 80)
      final XFile? foto = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (foto == null) return; // user batal memilih foto

      // Upload ke backend
      final api = ApiService();
      final response = await api.postMultipart(
        '/api/profil/foto',
        files: {'foto': File(foto.path)},
      );

      // Perbarui avatar langsung dari respons server
      if (response is Map) {
        final data = response['data'];
        if (data is Map && data['foto_url'] != null) {
          setState(() => _fotoUrl = data['foto_url'] as String);
        }
      }

      ref.invalidate(authStateProvider);
      _showMessage('Foto profil berhasil diperbarui.');
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingFoto = false);
    }
  }

  // ============ SIMPAN PROFIL ============
  Future<void> _simpanProfil() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final api = ApiService();
      await api.put(
        '/api/profil',
        data: {
          'nama': _namaController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'nomor_whatsapp': _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
        },
      );

      ref.invalidate(authStateProvider);

      _showMessage('Profil berhasil diperbarui.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============ GANTI PASSWORD ============
  Future<void> _gantiPassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    setState(() => _loadingPassword = true);

    try {
      final api = ApiService();
      await api.put(
        '/api/profil/password',
        data: {
          'current_password': _currentPassController.text,
          'new_password': _newPassController.text,
          'new_password_confirmation': _confirmPassController.text,
        },
      );

      _showMessage('Password berhasil diganti.');
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _loading || _loadingPassword || _loadingFoto,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ============ FOTO PROFIL (GALERI) ============
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(
                      url: _fotoUrl,
                      name: widget.user.nama,
                      radius: 44,
                    ),
                    Positioned(
                      bottom: 0,
                      right: -4,
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _loadingFoto ? null : _ubahFoto,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Ketuk ikon untuk memilih foto dari galeri',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ============ CARD: DATA PROFIL ============
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Data Profil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _namaController,
                        label: 'Nama Lengkap',
                        hint: 'Masukkan nama lengkap',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _usernameController,
                        label: 'Username Login',
                        hint: 'Masukkan username',
                        prefixIcon: Icons.account_circle_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username tidak boleh kosong';
                          }
                          if (value.trim().length < 3) {
                            return 'Username minimal 3 karakter';
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9_-]+$',
                          ).hasMatch(value.trim())) {
                            return 'Hanya huruf, angka, - dan _';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Username digunakan untuk login ke aplikasi',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email (Opsional)',
                        hint: 'Masukkan email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(value.trim())) {
                              return 'Format email tidak valid';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _whatsappController,
                        label: 'Nomor WhatsApp (Opsional)',
                        hint: 'Contoh: 08123456789',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        onPressed: _loading ? null : _simpanProfil,
                        label: 'Simpan Perubahan',
                        icon: Icons.save_outlined,
                        loading: _loading,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============ CARD: GANTI PASSWORD ============
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ganti Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _currentPassController,
                        label: 'Password Saat Ini',
                        hint: 'Masukkan password saat ini',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _showCurrentPass,
                        suffixIcon: _showCurrentPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () => setState(
                          () => _showCurrentPass = !_showCurrentPass,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password saat ini wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _newPassController,
                        label: 'Password Baru',
                        hint: 'Minimal 6 karakter',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _showNewPass,
                        suffixIcon: _showNewPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _showNewPass = !_showNewPass),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password baru wajib diisi';
                          }
                          if (value.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _confirmPassController,
                        label: 'Konfirmasi Password Baru',
                        hint: 'Ulangi password baru',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _showNewPass,
                        validator: (value) {
                          if (value != _newPassController.text) {
                            return 'Konfirmasi password tidak sama';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        onPressed: _loadingPassword ? null : _gantiPassword,
                        label: 'Ganti Password',
                        icon: Icons.key_outlined,
                        color: AppColors.secondary,
                        loading: _loadingPassword,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
