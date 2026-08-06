import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'absensi_screen.dart';

class AbsensiLuarJadwalScreen extends StatelessWidget {
  const AbsensiLuarJadwalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Absensi Luar Jadwal'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gunakan menu ini HANYA jika jam dinas Anda berubah atau bergeser dari jadwal roster (tukar shift mendadak). Absensi tetap SAH, tercatat sebagai absen biasa, dan tidak dihitung terlambat.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AbsensiScreen(type: 'masuk', mode: 'luar_jadwal'),
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Absen Masuk (Luar Jadwal)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AbsensiScreen(type: 'pulang', mode: 'luar_jadwal'),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Absen Pulang (Luar Jadwal)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🔒 Verifikasi foto & GPS tetap berlaku untuk mencegah penyalahgunaan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
