import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                (user?.nama ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.nama ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              user?.unitKerja ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
            ),

            const SizedBox(height: 32),

            // Info cards
            _InfoTile(
              icon: Icons.badge_outlined,
              label: 'NIK',
              value: user?.nik ?? '-',
            ),
            _InfoTile(
              icon: Icons.person_outline,
              label: 'Username',
              value: user?.username ?? '-',
            ),
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user?.email ?? '-',
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'WhatsApp',
              value: user?.nomorWhatsapp ?? '-',
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              label: 'Role',
              value: user?.role ?? '-',
            ),

            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Keluar',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
