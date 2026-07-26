import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
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
  final _picker = ImagePicker();

  late final TextEditingController _namaC = TextEditingController(
    text: widget.user.nama,
  );
  late final TextEditingController _emailC = TextEditingController(
    text: widget.user.email ?? '',
  );
  late final TextEditingController _waC = TextEditingController(
    text: widget.user.nomorWhatsapp ?? '',
  );
  bool _savingProfil = false;
  String? _profilError;

  final _curC = TextEditingController();
  final _newC = TextEditingController();
  final _confC = TextEditingController();
  bool _savingPass = false;
  String? _passError;
  bool _showCur = false, _showNew = false, _showConf = false;

  bool _uploadingFoto = false;

  // foto terkini: mulai dari user, diperbarui setelah upload sukses (lewat authState)
  String? get _fotoUrl =>
      ref.watch(authStateProvider).value?.fotoProfil ?? widget.user.fotoProfil;
  String get _namaNow =>
      _namaC.text.trim().isNotEmpty ? _namaC.text.trim() : widget.user.nama;

  @override
  void dispose() {
    _namaC.dispose();
    _emailC.dispose();
    _waC.dispose();
    _curC.dispose();
    _newC.dispose();
    _confC.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String? _empty(String v) => v.trim().isEmpty ? null : v.trim();

  // ---------------- FOTO PROFIL ----------------
  Future<void> _pilihSumberFoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Ambil dengan Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src != null) await _ambilDanUpload(src);
  }

  Future<void> _ambilDanUpload(ImageSource src) async {
    try {
      final x = await _picker.pickImage(
        source: src,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (x == null) return;
      setState(() => _uploadingFoto = true);
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/profil/foto',
        files: {'foto': File(x.path)},
      );
      if (res['success'] == true) {
        ref.invalidate(authStateProvider); // sinkronkan ke Home & Profil
        try {
          await ref.read(authStateProvider.future);
        } catch (_) {}
        _snack('Foto profil berhasil diperbarui.');
      } else {
        _snack(
          res['message']?.toString() ?? 'Gagal mengunggah foto.',
          ok: false,
        );
      }
    } catch (e) {
      _snack('Gagal mengunggah foto: $e', ok: false);
    } finally {
      if (mounted) setState(() => _uploadingFoto = false);
    }
  }

  // ---------------- SIMPAN PROFIL ----------------
  Future<void> _simpanProfil() async {
    if (_namaC.text.trim().isEmpty) {
      setState(() => _profilError = 'Nama wajib diisi.');
      return;
    }
    setState(() {
      _savingProfil = true;
      _profilError = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.put(
        '/profil',
        data: {
          'nama': _namaC.text.trim(),
          'email': _empty(_emailC.text),
          'nomor_whatsapp': _empty(_waC.text),
        },
      );
      if (res['success'] == true) {
        ref.invalidate(authStateProvider);
        try {
          await ref.read(authStateProvider.future);
        } catch (_) {}
        _snack('Profil berhasil diperbarui.');
      } else {
        setState(() => _profilError = res['message']?.toString());
      }
    } catch (e) {
      setState(() => _profilError = e.toString());
    } finally {
      if (mounted) setState(() => _savingProfil = false);
    }
  }

  // ---------------- GANTI PASSWORD ----------------
  Future<void> _gantiPassword() async {
    if (_curC.text.isEmpty) {
      setState(() => _passError = 'Password saat ini wajib diisi.');
      return;
    }
    if (_newC.text.length < 6) {
      setState(() => _passError = 'Password baru minimal 6 karakter.');
      return;
    }
    if (_newC.text != _confC.text) {
      setState(() => _passError = 'Konfirmasi password tidak cocok.');
      return;
    }
    setState(() {
      _savingPass = true;
      _passError = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.put(
        '/profil/password',
        data: {
          'current_password': _curC.text,
          'new_password': _newC.text,
          'new_password_confirmation': _confC.text,
        },
      );
      if (res['success'] == true) {
        _curC.clear();
        _newC.clear();
        _confC.clear();
        _snack('Password berhasil diubah.');
      } else {
        setState(() => _passError = res['message']?.toString());
      }
    } catch (e) {
      setState(() => _passError = e.toString());
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Profil & Keamanan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            // ===== FOTO PROFIL (dengan micro-interaction) =====
            Center(
              child: GestureDetector(
                onTap: _uploadingFoto ? null : _pilihSumberFoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Hero(
                      tag: 'profile-avatar',
                      child: Opacity(
                        opacity: _uploadingFoto ? 0.5 : 1,
                        child: ProfileAvatar(
                          url: _fotoUrl,
                          name: _namaNow,
                          radius: 48,
                        ),
                      ),
                    ),
                    if (_uploadingFoto)
                      Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    // badge kamera
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _uploadingFoto ? null : _pilihSumberFoto,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  _uploadingFoto ? 'Mengunggah...' : 'Ganti Foto Profil',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== DATA PROFIL =====
            _sectionLabel('Data Profil'),
            const SizedBox(height: 12),
            _card([
              TextFormField(
                controller: _namaC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (opsional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _waC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp (opsional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 18),
              if (_profilError != null) ...[
                _errorBox(_profilError!),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _savingProfil ? null : _simpanProfil,
                  icon: _savingProfil
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _savingProfil ? 'Menyimpan...' : 'Simpan Perubahan',
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 28),

            // ===== GANTI PASSWORD =====
            _sectionLabel('Ganti Password'),
            const SizedBox(height: 12),
            _card([
              TextFormField(
                controller: _curC,
                obscureText: !_showCur,
                decoration: InputDecoration(
                  labelText: 'Password Saat Ini',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showCur ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _showCur = !_showCur),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newC,
                obscureText: !_showNew,
                decoration: InputDecoration(
                  labelText: 'Password Baru (min. 6)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNew ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confC,
                obscureText: !_showConf,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConf ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _showConf = !_showConf),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_passError != null) ...[
                _errorBox(_passError!),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _savingPass ? null : _gantiPassword,
                  icon: _savingPass
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.key_outlined),
                  label: Text(_savingPass ? 'Memproses...' : 'Ganti Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
    t.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: AppColors.textHint,
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _errorBox(String t) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
