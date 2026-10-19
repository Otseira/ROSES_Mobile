import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profil_screen.dart';
import '../../../core/widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storedUser = ref.watch(authStateProvider).value;
    final freshUser = ref.watch(freshProfileProvider).value;
    final user = freshUser ?? storedUser;
    final nama = user?.nama ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Edit Profil',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfilScreen(user: user)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // === 1. HEADER AVATAR & IDENTITAS RINGKAS ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Hero(
                    tag: 'profile-avatar',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 2.5,
                        ),
                      ),
                      child: ProfileAvatar(
                        url: user?.fotoProfil,
                        name: nama.isEmpty ? 'U' : nama,
                        radius: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.nama ?? 'Karyawan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if ((user?.unitKerja ?? '').isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user!.unitKerja!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // === 2. KARTU INFORMASI AKUN GROUPED (BERSIH & MUDAH DIBACA) ===
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _GroupedInfoRow(
                    icon: Icons.badge_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: 'Nomor Induk Karyawan (NIK)',
                    value: user?.nik ?? '-',
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.divider),
                  _GroupedInfoRow(
                    icon: Icons.person_outline_rounded,
                    iconColor: AppColors.info,
                    iconBg: AppColors.infoSoft,
                    label: 'Username Sistem',
                    value: user?.username ?? '-',
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.divider),
                  _GroupedInfoRow(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF6366F1),
                    iconBg: const Color(0xFFEEF2FF),
                    label: 'Alamat Email',
                    value: user?.email ?? '-',
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.divider),
                  _GroupedInfoRow(
                    icon: Icons.phone_outlined,
                    iconColor: AppColors.success,
                    iconBg: AppColors.successSoft,
                    label: 'Nomor WhatsApp',
                    value: user?.nomorWhatsapp ?? '-',
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.divider),
                  _GroupedInfoRow(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.warning,
                    iconBg: AppColors.warningSoft,
                    label: 'Hak Akses / Peran',
                    value: user?.role ?? '-',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // === 3. TOMBOL AKSI UTAMA (BESAR & JELAS) ===
            if (user != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfilScreen(user: user),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text(
                    'Ubah Profil & Kata Sandi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Tombol Logout dengan gaya modern & peringatan jelas
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                  backgroundColor: AppColors.errorSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini? Sesi login Anda di perangkat ini akan diakhiri.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(authNotifierProvider.notifier).logout();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

/// Baris Informasi Profil Grouped
class _GroupedInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  const _GroupedInfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
