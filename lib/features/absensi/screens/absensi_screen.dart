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
  const AbsensiScreen({super.key, required this.type});

  @override
  ConsumerState<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends ConsumerState<AbsensiScreen> {
  final _cameraService = CameraService();
  final _locationService = LocationService();

  bool _cameraReady = false;
  bool _processing = false;
  String? _error;

  bool get isMasuk => widget.type == 'masuk';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.init(frontCamera: true);
      setState(() => _cameraReady = true);
    } catch (e) {
      setState(() => _error = 'Gagal membuka kamera.');
    }
  }

  Future<void> _submitAbsensi() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // 1. Capture photo (KAMERA ONLY)
      final photo = await _cameraService.capture();

      // 2. Get validated location (ANTI SPOOF)
      final loc = await _locationService.getValidatedLocation();

      if (!loc.success) {
        setState(() {
          _error = loc.error;
          _processing = false;
        });
        if (loc.isMocked) _showMockDialog(loc.mockDetails);
        return;
      }

      // 3. Send to API
      final api = ref.read(apiServiceProvider);
      final endpoint = isMasuk ? '/absensi/masuk' : '/absensi/pulang';

      final response = await api.postMultipart(
        endpoint,
        fields: {
          'latitude': loc.latitude.toString(),
          'longitude': loc.longitude.toString(),
        },
        files: {'foto': photo},
      );

      if (response['success'] == true) {
        _showSuccess(response);
      } else {
        setState(() {
          _error = response['message'] ?? 'Absensi gagal.';
          _processing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
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

  void _showSuccess(Map<String, dynamic> response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 56,
        ),
        title: Text(
          isMasuk ? 'Absen Masuk Berhasil!' : 'Absen Pulang Berhasil!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(response['message'] ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (response['data']?['status_kehadiran'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: response['data']['status_kehadiran'] == 'Terlambat'
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  response['data']['status_kehadiran'],
                  style: TextStyle(
                    color: response['data']['status_kehadiran'] == 'Terlambat'
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                        // Back button
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
                        // Label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMasuk
                                ? AppColors.success
                                : AppColors.secondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isMasuk ? 'ABSEN MASUK' : 'ABSEN PULANG',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
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
                          color: Colors.white.withValues(alpha: 0.5),
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
                  // GPS Status
                  _buildGpsIndicator(),
                  const SizedBox(height: 16),

                  // Error
                  if (_error != null) ...[
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
                      icon: _processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 22),
                      label: Text(
                        _processing
                            ? 'Memproses...'
                            : 'Foto & ${isMasuk ? "Absen Masuk" : "Absen Pulang"}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMasuk
                            ? AppColors.success
                            : AppColors.secondary,
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
