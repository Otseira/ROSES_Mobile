import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

class LemburScreen extends ConsumerStatefulWidget {
  const LemburScreen({super.key});
  @override
  ConsumerState<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends ConsumerState<LemburScreen> {
  final _locationService = LocationService();
  bool _processing = false;
  bool _loading = true;
  Map<String, dynamic>? _onCallAktif;

  @override
  void initState() {
    super.initState();
    _cekOnCallAktif();
  }

  Future<void> _cekOnCallAktif() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/lembur/oncall-aktif');
      if (!mounted) return;
      setState(() {
        _onCallAktif = (res['success'] == true) ? res['data'] : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _ambilLokasi() async {
    final loc = await _locationService.getValidatedLocation();
    if (!loc.success) {
      if (mounted) _snack(loc.error ?? 'Lokasi gagal diambil.');
      return null;
    }
    return loc;
  }

  // ================= EKSTENSI SHIFT (1x tekan, durasi default otomatis) =================
  Future<void> _alurEkstensi() async {
    if (_processing) return;

    Map<String, dynamic>? shiftInfo;
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/absensi/info-shift');
      if (res['success'] == true) shiftInfo = res['data'];
    } catch (_) {}

    if (shiftInfo == null) {
      _snack('Anda tidak memiliki jadwal shift hari ini. Gunakan On-Call.');
      return;
    }
    if ((shiftInfo['max_menit'] ?? 0) < 1) {
      _snack(
        'Ekstensi shift baru bisa setelah jam pulang (${shiftInfo['jam_pulang']}).',
      );
      return;
    }

    final form = await _showFormEkstensi(shiftInfo);
    if (form == null) return;

    final loc = await _ambilLokasi();
    if (loc == null) return;

    final foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraPage(label: 'Foto Bukti Lembur'),
      ),
    );
    if (foto == null) return;

    setState(() => _processing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/lembur/ekstensi',
        fields: {
          'keterangan': form['keterangan'],
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
          'durasi_menit': form['durasi'].toString(),
        },
        files: {'foto_masuk': foto},
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(authStateProvider);
        await _showSuksesDialog(
          'Ekstensi Shift',
          res['data'],
          form['keterangan'],
        );
      } else {
        _snack(res['message'] ?? 'Gagal menyimpan lembur.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ================= ON-CALL MASUK (mirip absen masuk) =================
  Future<void> _alurOnCallMasuk() async {
    if (_processing) return;

    final ket = await _showKeteranganDialog();
    if (ket == null) return;

    final loc = await _ambilLokasi();
    if (loc == null) return;

    final foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraPage(label: 'Foto On-Call Masuk'),
      ),
    );
    if (foto == null) return;

    setState(() => _processing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/lembur/oncall-masuk',
        fields: {
          'keterangan': ket,
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
        },
        files: {'foto_masuk': foto},
      );
      if (!mounted) return;
      if (res['success'] == true) {
        await _showPesanDialog(
          'On-Call Masuk Tercatat ✓',
          'Mulai On-Call: ${res['data']['waktu_mulai']}\nKasus: $ket\n\nJangan lupa lakukan On-Call Keluar saat tugas selesai.',
        );
        _cekOnCallAktif();
      } else {
        _snack(res['message'] ?? 'Gagal memulai On-Call.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ================= ON-CALL KELUAR (menyerupai lembur) =================
  Future<void> _alurOnCallKeluar() async {
    if (_processing || _onCallAktif == null) return;

    final mulai = DateFormat(
      'HH:mm',
    ).format(DateTime.parse(_onCallAktif!['waktu_mulai_lembur']));

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.phone_callback_outlined,
          color: AppColors.info,
          size: 44,
        ),
        title: const Text('Selesaikan On-Call?'),
        content: Text(
          'Sesi On-Call Anda dimulai pukul $mulai.\n\nDurasi akan dihitung otomatis sampai sekarang, dan jam dinas Anda akan diakhiri otomatis jika belum absen pulang.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final loc = await _ambilLokasi();
    if (loc == null) return;

    final foto = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraPage(label: 'Foto On-Call Keluar'),
      ),
    );
    if (foto == null) return;

    setState(() => _processing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.postMultipart(
        '/lembur/oncall-keluar',
        fields: {
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
        },
        files: {'foto_keluar': foto},
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(authStateProvider);
        await _showSuksesDialog(
          'On-Call',
          res['data'],
          _onCallAktif?['keterangan'] ?? '',
        );
        _cekOnCallAktif();
      } else {
        _snack(res['message'] ?? 'Gagal menyelesaikan On-Call.');
      }
    } catch (_) {
      if (mounted) _snack('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ================= DIALOG & WIDGET =================
  Future<Map<String, dynamic>?> _showFormEkstensi(
    Map<String, dynamic> shiftInfo,
  ) {
    final int maxMenit = (shiftInfo['max_menit'] as int?) ?? 0;
    final durasiC = TextEditingController(text: maxMenit.toString());
    final ketC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ekstensi Shift',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '⏱ Terisi otomatis: ${shiftInfo['jam_pulang']} s/d sekarang ($maxMenit menit). Boleh diubah, rentang 1 – $maxMenit menit. Jam dinas Anda akan diakhiri otomatis.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Durasi Lembur (1 – $maxMenit menit)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: durasiC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.timer_outlined),
                    suffixText: 'menit',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null) return 'Wajib diisi angka';
                    if (n < 1) return 'Minimal 1 menit';
                    if (n > maxMenit) return 'Maksimal $maxMenit menit';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
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

  Future<String?> _showKeteranganDialog() {
    final ketC = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_callback_outlined, color: AppColors.info),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'On-Call Masuk',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ketC,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Kasus / alasan on-call…',
            prefixIcon: Icon(Icons.edit_note),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ketC.text.trim()),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Lanjut Foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

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
        title: const Text('Selesai Tercatat!', textAlign: TextAlign.center),
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
            _InfoRow(label: 'Mulai', value: '${data['waktu_mulai']}'),
            _InfoRow(label: 'Selesai', value: '${data['waktu_selesai']}'),
            _InfoRow(
              label: 'Durasi',
              value: '${data['total_menit']} menit',
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
              onPressed: () => Navigator.pop(ctx),
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

  Future<void> _showPesanDialog(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle, color: AppColors.info, size: 48),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _processing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cekOnCallAktif,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== LEMBUR EKSTENSI =====
                    _MenuLemburCard(
                      icon: Icons.add_task_outlined,
                      title: 'Ekstensi Shift',
                      subtitle:
                          'Akhiri jam dinas + catat lembur setelah shift (1x tekan)',
                      color: AppColors.warning,
                      onTap: _alurEkstensi,
                    ),
                    const SizedBox(height: 14),

                    // ===== ON-CALL =====
                    if (_onCallAktif == null)
                      _MenuLemburCard(
                        icon: Icons.phone_callback_outlined,
                        title: 'On-Call Masuk',
                        subtitle: 'Mulai tugas on-call (seperti absen masuk)',
                        color: AppColors.info,
                        onTap: _alurOnCallMasuk,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.phone_in_talk_outlined,
                                    color: AppColors.info,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'On-Call Aktif',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Masuk pukul ${DateFormat('HH:mm').format(DateTime.parse(_onCallAktif!['waktu_mulai_lembur']))}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _alurOnCallKeluar,
                                icon: const Icon(Icons.call_end_outlined),
                                label: const Text(
                                  'On-Call Keluar (Selesaikan)',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.info,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
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
    );
  }
}

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
            width: 100,
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

class _CameraPage extends StatefulWidget {
  final String label;
  const _CameraPage({required this.label});
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
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '📸 ${widget.label}',
                style: const TextStyle(
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
