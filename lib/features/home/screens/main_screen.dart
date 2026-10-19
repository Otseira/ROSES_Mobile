import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import 'home_screen.dart';
import '../../roster/screens/jadwal_dinas_screen.dart';
import '../../lembur/screens/lembur_screen.dart';
import '../../lembur/screens/validasi_lembur_screen.dart';
import '../../profile/screens/profile_screen.dart';

/// Shell Navigasi Utama dengan Floating Bottom Navigation Bar Modern.
/// Menu 'Validasi' otomatis muncul bila pengguna memiliki hak akses (user.canValidasi).
/// Menggunakan IndexedStack agar status halaman tidak ter-reset saat berpindah tab.
class MainScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final storedUser = ref.watch(authStateProvider).value;
    final freshUser = ref.watch(freshProfileProvider).value;
    final user = freshUser ?? storedUser;
    final canValidasi = user?.canValidasi == true;

    final screens = [
      HomeScreen(onNavigateTab: _onTabTapped),
      const JadwalDinasScreen(),
      const LemburScreen(),
      if (canValidasi) const ValidasiLemburScreen(),
      const ProfileScreen(),
    ];

    // Mencegah index out of range jika hak akses berubah
    final activeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: activeIndex,
        children: screens,
      ),
      bottomNavigationBar: _FloatingBottomNavBar(
        currentIndex: activeIndex,
        canValidasi: canValidasi,
        onTap: _onTabTapped,
      ),
    );
  }
}

/// Floating Navigation Bar yang mengambang, ramah jempol, dan modern
class _FloatingBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool canValidasi;
  final ValueChanged<int> onTap;

  const _FloatingBottomNavBar({
    required this.currentIndex,
    required this.canValidasi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        bottomPadding > 0 ? bottomPadding : 12,
      ),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 0: Beranda
            _NavBarItem(
              icon: Icons.home_rounded,
              label: 'Beranda',
              isCompact: canValidasi,
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            // 1: Jadwal
            _NavBarItem(
              icon: Icons.calendar_month_rounded,
              label: 'Jadwal',
              isCompact: canValidasi,
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            // 2: Lembur
            _NavBarItem(
              icon: Icons.more_time_rounded,
              label: 'Lembur',
              isCompact: canValidasi,
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            // 3: Validasi (Khusus bila canValidasi == true)
            if (canValidasi)
              _NavBarItem(
                icon: Icons.fact_check_rounded,
                label: 'Validasi',
                isCompact: true,
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            // 4 (atau 3): Profil
            _NavBarItem(
              icon: Icons.person_rounded,
              label: 'Profil',
              isCompact: canValidasi,
              isSelected: currentIndex == (canValidasi ? 4 : 3),
              onTap: () => onTap(canValidasi ? 4 : 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item tombol individual dengan animasi transisi pill lembut
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isCompact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? (isCompact ? 10 : 16) : (isCompact ? 6 : 10),
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isCompact ? 20 : 22,
                color: isSelected ? AppColors.primary : AppColors.textHint,
              ),
              if (isSelected) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
