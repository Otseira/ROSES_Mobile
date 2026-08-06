import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/api_service.dart';

class AbsensiScreen extends ConsumerStatefulWidget {
  final String type; // 'masuk' | 'pulang'
  final String mode; // 'normal' | 'luar_jadwal'
  const AbsensiScreen({super.key, required this.type, this.mode = 'normal'});

  @override
  ConsumerState<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends ConsumerState<AbsensiScreen> {
  final _cameraService = CameraService();
  final _locationService = LocationService();

  bool _cameraReady = false;
  bool _processing = false;
  String? _error;
  String _status = '';

  Future<dynamic>? _locFuture;
  DateTime? _locStartedAt;
  dynamic _locResult;

  bool get isMasuk => widget.type == 'masuk';
  bool get isLuarJadwal => widget.mode == 'luar_jadwal'; // ✅ NEW

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationPreValidation();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.init(frontCamera: true);
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membuka kamera.');
    }
  }

  void _startLocationPreValidation() {
    _locStartedAt = DateTime.now();
    _locFuture = _locationService.getValidatedLocation().then((result) {
      _locResult = result;
      return result;
    });
  }

  Future<dynamic> _getFastLocation() async {
    if (_locFuture != null &&
        _locStartedAt != null &&
        DateTime.now().difference(_locStartedAt!) <
            const Duration(seconds: 90)) {
      return _locResult ?? await _locFuture!;
    }
    _startLocationPreValidation();
    return await _locFuture!;
  }

  Future<File> _compressFoto(String sourcePath) async {
    final target =
        '${Directory.systemTemp.path}/absen_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        target,
        minWidth: 720,
        quality: 65,
      );

      if (result != null) {
        return File(result.path);
      }
      return File(sourcePath);
    } catch (_) {
      return File(sourcePath);
    }
  }

  Future<void> _submitAbsensi() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Mengambil foto…';
    });

    try {
      final photo = await _cameraService.capture();

      if (mounted) setState(() => _status = 'Mengoptimalkan foto…');
      final compressed = await _compressFoto(photo.path);

      if (mounted) setState(() => _status = 'Memverifikasi lokasi…');
      final loc = await _getFastLocation();

      if (!loc.success) {
        if (mounted) {
          setState(() {
            _error = loc.error;
            _processing = false;
            _status = '';
          });
          if (loc.isMocked) _showMockDialog(loc.mockDetails);
        }
        return;
      }

      if (mounted) setState(() => _status = 'Mengirim absensi…');
      final api = ref.read(apiServiceProvider);
      final endpoint = isMasuk ? '/absensi/masuk' : '/absensi/pulang';

      final response = await api.postMultipart(
        endpoint,
        fields: {
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
          'mode': widget.mode, // ✅ kirim mode
        },
        files: {'foto': compressed},
      );

      if (response['success'] == true) {
        _showSuccess(response);
      } else {
        // ✅ NEW: Tangani kode khusus OUTSIDE_WINDOW
        if (response['code'] == 'OUTSIDE_WINDOW' && mounted) {
          _showOutsideWindowDialog(response['message'] ?? '');
          setState(() {
            _processing = false;
            _status = '';
          });
          return;
        }

        if (mounted) {
          setState(() {
            _error = response['message'] ?? 'Absensi gagal.';
            _processing = false;
            _status = '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _processing = false;
          _status = '';
        });
      }
    }
  }

  // ✅ NEW: Dialog saat user di luar jendela shift (mode normal)
  void _showOutsideWindowDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.access_time_filled,
          color: AppColors.warning,
          size: 48,
        ),
        title: const Text(
          'Di Luar Jam Jadwal Dinas',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silakan kembali ke Beranda, lalu buka menu "Absensi Luar Jadwal".',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // kembali ke home
            },
            child: const Text('Kembali ke Beranda'),
          ),
        ],
      ),
    );
  }

  void _showMockDialog(Map<String, bool>? details) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.gps_off, color: AppColors.error, size: 48),
        title: const Text(
          'Lokasi Palsu Terdeteksi',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sistem mendeteksi penggunaan Fake GPS.\nAbsensi tidak dapat dilanjutkan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              ...details.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        e.value ? Icons.warning : Icons.check_circle,
                        size: 16,
                        color: e.value ? AppColors.error : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${e.key}: ${e.value ? "Terdeteksi" : "Aman"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: e.value ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Dialog sukses dengan support luar_jadwal
  void _showSuccess(Map<String, dynamic> response) {
    final data = response['data'] as Map<String, dynamic>?;
    final jenisAbsen = data?['jenis_absen'] as String?;
    final isLuar = jenisAbsen == 'luar_jadwal';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.check_circle,
          color: isLuar ? AppColors.warning : AppColors.success,
          size: 56,
        ),
        title: Text(
          isMasuk ? 'Absen Masuk Berhasil!' : 'Absen Pulang Berhasil!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ NEW: Badge luar jadwal
            if (isLuar) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horizontal_circle_outlined,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'LUAR JADWAL',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              response['message'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (data?['status_kehadiran'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: data!['status_kehadiran'] == 'Terlambat'
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data['status_kehadiran'],
                  style: TextStyle(
                    color: data['status_kehadiran'] == 'Terlambat'
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // ✅ NEW: Info tambahan untuk luar jadwal
            if (isLuar) ...[
              const SizedBox(height: 12),
              const Text(
                'Absensi ini tetap sah dan tercatat sebagai absen biasa dalam laporan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Kembali'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // === CAMERA PREVIEW ===
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cameraReady
                      ? CameraPreview(_cameraService.controller!)
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),

                  // Top overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        GestureDetector(
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
                        const Spacer(),
                        // ✅ UPDATED: Label badge dengan support luar_jadwal
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isLuarJadwal
                                ? AppColors.warning
                                : (isMasuk
                                      ? AppColors.success
                                      : AppColors.secondary),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLuarJadwal) ...[
                                const Icon(
                                  Icons.swap_horizontal_circle_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isLuarJadwal
                                    ? (isMasuk
                                          ? 'MASUK (LUAR JADWAL)'
                                          : 'PULANG (LUAR JADWAL)')
                                    : (isMasuk
                                          ? 'ABSEN MASUK'
                                          : 'ABSEN PULANG'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Face guide circle
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLuarJadwal
                              ? AppColors.warning.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Posisikan wajah\ndi dalam lingkaran',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Loading overlay
                  if (_processing)
                    Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 28,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _status,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Mohon tunggu sebentar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // === BOTTOM PANEL ===
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ NEW: Banner info untuk mode luar jadwal
                  if (isLuarJadwal) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode Luar Jadwal — Absensi tetap SAH tanpa dihitung terlambat.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // GPS Status
                  _buildGpsIndicator(),
                  const SizedBox(height: 16),

                  // Error
                  if (_error != null && !_processing) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_cameraReady && !_processing)
                          ? _submitAbsensi
                          : null,
                      icon: const Icon(Icons.camera_alt_rounded, size: 22),
                      label: Text(
                        isLuarJadwal
                            ? 'Foto & ${isMasuk ? "Absen Masuk" : "Absen Pulang"} (Luar Jadwal)'
                            : 'Foto & ${isMasuk ? "Absen Masuk" : "Absen Pulang"}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLuarJadwal
                            ? AppColors.warning
                            : (isMasuk
                                  ? AppColors.success
                                  : AppColors.secondary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    '🔒 Foto diambil langsung dari kamera. Galeri tidak tersedia.',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsIndicator() {
    return FutureBuilder<bool>(
      future: Geolocator.isLocationServiceEnabled(),
      builder: (ctx, snap) {
        final active = snap.data ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              active
                  ? 'GPS Aktif — Siap absensi'
                  : 'GPS Nonaktif — Aktifkan GPS',
              style: TextStyle(
                fontSize: 13,
                color: active ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}
