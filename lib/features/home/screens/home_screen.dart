import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../absensi/screens/absensi_screen.dart';
import '../../lembur/screens/lembur_screen.dart';
import '../../roster/screens/jadwal_dinas_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../lembur/screens/validasi_lembur_screen.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../absensi/screens/absensi_luar_jadwal_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ PERBAIKAN: ambil user terbaru dari server agar role ikut berubah
    final storedUser = ref.watch(authStateProvider).value;
    final freshUser = ref.watch(freshProfileProvider).value;
    final user = freshUser ?? storedUser;

    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(authStateProvider);
            ref.invalidate(freshProfileProvider);
          },
          child: CustomScrollView(
            slivers: [
              // === HEADER ===
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Row(
                        children: [
                          ProfileAvatar(
                            url: user?.fotoProfil,
                            name: user?.nama ?? 'U',
                            radius: 24,
                            onDark: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, ${user?.nama ?? "User"} 👋',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.unitKerja ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Date
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(now),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // === QUICK ACTIONS ===
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Absensi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.login_rounded,
                              label: 'Absen Masuk',
                              color: AppColors.success,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AbsensiScreen(type: 'masuk'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.logout_rounded,
                              label: 'Absen Pulang',
                              color: AppColors.secondary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AbsensiScreen(type: 'pulang'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      const Text(
                        'Lainnya',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.timer_outlined,
                              label: 'Lembur/On Call',
                              color: AppColors.info,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LemburScreen(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.calendar_month_outlined,
                              label: 'Jadwal Dinas',
                              color: AppColors.primary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const JadwalDinasScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.swap_horizontal_circle_outlined,
                              label: 'Absensi Luar Jadwal',
                              color: AppColors.warning,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AbsensiLuarJadwalScreen(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),

                      // ✅ PERBAIKAN: Validasi Lembur — pakai Row + Expanded agar icon seragam
                      if (user?.canValidasi == true) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: Icons.fact_check_outlined,
                                label: 'Validasi Lembur',
                                color: AppColors.secondary,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ValidasiLemburScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Placeholder kosong agar layout tetap 2 kolom & simetris
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],

                      // === INFO CARD ===
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pastikan GPS aktif dan berada di area rumah sakit saat melakukan absensi. Foto diambil langsung dari kamera.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
