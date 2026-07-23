import 'dart:async'; // ✅ WAJIB untuk TimeoutException
import 'package:geolocator/geolocator.dart';
import '../utils/mock_location_detector.dart';

class LocationService {
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

    // 4. Get position
    try {
      // ✅ getCurrentPosition() tanpa named param + .timeout()
      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );

      // 5. Accuracy check (default accuracy sudah best/high, tetap kita validasi)
      if (position.accuracy > 50) {
        return LocationResult.failure(
          'Akurasi GPS rendah (${position.accuracy.round()}m). Pindah ke area terbuka.',
        );
      }

      return LocationResult(
        success: true,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } on TimeoutException {
      // ✅ Sekarang valid karena sudah import dart:async
      return LocationResult.failure(
        'Timeout mendapatkan lokasi. Pastikan GPS aktif.',
      );
    } catch (e) {
      return LocationResult.failure('Gagal mendapatkan lokasi: $e');
    }
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
