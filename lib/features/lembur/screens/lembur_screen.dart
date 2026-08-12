import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/camera_service.dart';
import '../../auth/providers/auth_provider.dart';

class LemburScreen extends ConsumerStatefulWidget {
  const LemburScreen({super.key});

  @override
  ConsumerState<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends ConsumerState<LemburScreen> {
  bool _processing = false;

  // =====================================================
  // ALUR UTAMA: Form → Foto → Submit → Dialog Selesai → OK
  // =====================================================
  Future<void> _alurLembur(String jenis) async {
    if (_processing) return;

    // ===== STEP 1: Form keterangan & durasi muncul langsung =====
    final form = await _showFormDialog(jenis);
    if (form == null) return; // user batal

    // ===== STEP 2: Ambil foto bukti =====
    final foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const _CameraPage()),
    );
    if (foto == null) return; // user batal foto

    // ===== STEP 3: Kirim ke server =====
    setState(() => _processing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.postMultipart(
        '/lembur/langsung-selesai',
        fields: {
          'jenis_lembur': jenis,
          'durasi_menit': form['durasi'].toString(),
          'keterangan': form['keterangan'],
        },
        files: {'foto': foto},
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ref.invalidate(authStateProvider); // update status absen pulang di home

        // ===== STEP 4: Dialog "LEMBUR SELESAI" =====
        await _showSuksesDialog(jenis, response['data'], form['keterangan']);
        // Setelah OK ditekan → dialog hilang, selesai.
      } else {
        _snack(response['message'] ?? 'Gagal menyimpan lembur.');
      }
    } catch (e) {
      if (mounted) _snack('Gagal terhubung ke server. Coba lagi.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // =====================================================
  // STEP 1 — FORM KETERANGAN & DURASI
  // =====================================================
  Future<Map<String, dynamic>?> _showFormDialog(String jenis) {
    final durasiC = TextEditingController(text: '60');
    final ketC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                jenis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info auto clock-out
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'ℹ️ Absen pulang otomatis tercatat. Isi durasi & keterangan lembur Anda.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Durasi
                const Text(
                  'Durasi Lembur (menit)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: durasiC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 90',
                    prefixIcon: Icon(Icons.timer_outlined),
                    suffixText: 'menit',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null) return 'Wajib diisi angka';
                    if (n < 15) return 'Minimal 15 menit';
                    if (n > 720) return 'Maksimal 720 menit';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [30, 60, 90, 120, 180].map((m) {
                    return ChoiceChip(
                      label: Text('$m mnt'),
                      selected: durasiC.text == m.toString(),
                      onSelected: (_) => durasiC.text = m.toString(),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Keterangan
                const Text(
                  'Keterangan Lembur',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ketC,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Menyelesaikan laporan stok obat…',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, {
                  'durasi': int.parse(durasiC.text),
                  'keterangan': ketC.text.trim(),
                });
              }
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Lanjut Foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // STEP 4 — DIALOG "LEMBUR SELESAI" (OK → pesan hilang)
  // =====================================================
  Future<void> _showSuksesDialog(
    String jenis,
    Map<String, dynamic> data,
    String keterangan,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.verified, color: AppColors.success, size: 52),
        title: const Text('Lembur Selesai!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data['auto_clock_out'] == true) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Absen pulang otomatis tercatat',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _InfoRow(label: 'Jenis', value: jenis),
            _InfoRow(label: 'Mulai Lembur', value: '${data['waktu_mulai']}'),
            _InfoRow(
              label: 'Selesai Lembur',
              value: '${data['waktu_selesai']}',
            ),
            _InfoRow(
              label: 'Durasi',
              value:
                  '${data['total_menit']} menit (${((data['total_menit'] as int) / 60).toStringAsFixed(1)} jam)',
              highlight: true,
            ),
            if (keterangan.isNotEmpty)
              _InfoRow(label: 'Keterangan', value: keterangan),

            const SizedBox(height: 12),
            const Text(
              'Status: Menunggu validasi atasan',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx), // ✅ OK → pesan hilang
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lembur / On-Call'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      '⏱ Tekan tombol di bawah → isi keterangan → ambil foto → lembur langsung tercatat selesai dan absen pulang otomatis tersimpan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _MenuLemburCard(
                    icon: Icons.add_task_outlined,
                    title: 'Ekstensi Shift',
                    subtitle:
                        'Lembur setelah jam pulang shift — dihitung dari akhir shift',
                    color: AppColors.warning,
                    onTap: () => _alurLembur('Ekstensi Shift'),
                  ),
                  const SizedBox(height: 14),
                  _MenuLemburCard(
                    icon: Icons.phone_callback_outlined,
                    title: 'On-Call',
                    subtitle: 'Dipanggil bertugas di luar jadwal dinas',
                    color: AppColors.info,
                    onTap: () => _alurLembur('On-call'),
                  ),
                ],
              ),
            ),
    );
  }
}

// ===== Widget kartu menu =====
class _MenuLemburCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuLemburCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ===== Baris info pada dialog sukses =====
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: highlight ? 14 : 12,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// HALAMAN KAMERA (ambil foto bukti)
// =====================================================
class _CameraPage extends StatefulWidget {
  const _CameraPage();

  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> {
  final _cam = CameraService();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _cam.init(frontCamera: true).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      final photo = await _cam.capture();
      if (mounted) Navigator.pop(context, File(photo.path));
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ready
              ? CameraPreview(_cam.controller!)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          const Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '📸 Foto Bukti Lembur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _ready ? _capture : null,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Ambil Foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
