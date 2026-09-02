import 'dart:async'; // ✅ WAJIB untuk TimeoutException
import 'package:geolocator/geolocator.dart';
import '../utils/mock_location_detector.dart';

class LocationService {
  // ✅ KONFIGURASI GPS ADAPTIF
  static const double _targetAccuracy = 20.0; // meter (ideal)
  static const double _maxAcceptableAccuracy = 50.0; // meter (batas atas)
  static const Duration _maxExtraWait = Duration(seconds: 3);
  static const Duration _initialTimeout = Duration(seconds: 10);

  Future<LocationResult> getValidatedLocation() async {
    // 1. Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.failure(
          'Izin lokasi ditolak. Aktifkan izin lokasi di pengaturan.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationResult.failure(
        'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.',
      );
    }

    // 2. GPS enabled
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!gpsEnabled) {
      return LocationResult.failure('GPS tidak aktif. Silakan aktifkan GPS.');
    }

    // 3. Mock detection
    final mockResult = await MockLocationDetector.detect();
    if (mockResult.isMocked) {
      return LocationResult(
        success: false,
        isMocked: true,
        mockDetails: mockResult.details,
        error:
            'Terdeteksi penggunaan lokasi palsu (Fake GPS).\nRisiko: ${mockResult.riskLevel}',
      );
    }

    // 4. ✅ GPS ADAPTIF
    try {
      final position = await _getAdaptivePosition();

      // 5. Accuracy check — batas atas 50m
      if (position.accuracy > _maxAcceptableAccuracy) {
        return LocationResult.failure(
          'Akurasi GPS rendah (${position.accuracy.round()}m). Pindah ke area terbuka atau dekat jendela.',
        );
      }

      return LocationResult(
        success: true,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } on TimeoutException {
      return LocationResult.failure(
        'Timeout mendapatkan lokasi. Pastikan GPS aktif & sinyal satelit cukup.',
      );
    } catch (e) {
      return LocationResult.failure('Gagal mendapatkan lokasi: $e');
    }
  }

  /// ✅ GPS ADAPTIF — kompatibel SEMUA versi geolocator
  /// (tanpa named parameter, sama seperti mock_location_detector.dart)
  ///
  /// 1. Ambil posisi pertama (warm start, timeout 10 dtk).
  /// 2. Akurasi ≤ 20 m → LANGSUNG return (0 dtk tambahan).
  /// 3. Akurasi buruk → sampling lanjutan maks 3 dtk, return posisi TERBAIK.
  Future<Position> _getAdaptivePosition() async {
    final sw = Stopwatch()..start();

    // 1. Pengambilan pertama (warm start)
    Position best = await Geolocator.getCurrentPosition().timeout(
      _initialTimeout,
    );

    // ✅ Sudah akurat → langsung pakai, tanpa delay tambahan
    if (best.accuracy <= _targetAccuracy) {
      return best;
    }

    // 2. Akurasi jelek → cari sample lebih baik (dibatasi waktu)
    while (sw.elapsed < _maxExtraWait) {
      try {
        await Future.delayed(const Duration(milliseconds: 300));

        final p = await Geolocator.getCurrentPosition().timeout(
          const Duration(seconds: 2),
        );

        if (p.accuracy < best.accuracy) {
          best = p;
        }
        if (best.accuracy <= _targetAccuracy) {
          break;
        }
      } catch (_) {
        // Sample gagal, lanjut iterasi berikutnya
        continue;
      }
    }

    return best; // posisi TERBAIK yang didapat
  }
}

class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? error;
  final bool isMocked;
  final Map<String, bool>? mockDetails;

  LocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.error,
    this.isMocked = false,
    this.mockDetails,
  });

  factory LocationResult.failure(String error) {
    return LocationResult(success: false, error: error);
  }
}
