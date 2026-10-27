import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class MockLocationDetector {
  static const _channel = MethodChannel('com.siro/mock_detection');

  static Future<MockLocationResult> detect() async {
    final results = <String, bool>{};

    // Layer 1: Geolocator built-in provider check
    results['geolocator'] = await _checkGeolocator();

    // Layer 2: Native Android deep checks
    if (Platform.isAndroid) {
      results['developer_mode'] = await _checkNative('isDeveloperOptionsEnabled');
      results['mock_apps'] = await _checkNative('isMockLocationAppInstalled');
      results['mock_enabled'] = await _checkNative('isMockLocationEnabled');
      results['device_rooted'] = await _checkNative('isDeviceRooted');
      results['emulator'] = await _checkNative('isEmulator');
    }

    // Layer 3: Location consistency & teleportation check
    results['consistency'] = await _checkConsistency();

    final isMocked = results.values.any((v) => v);

    return MockLocationResult(
      isMocked: isMocked,
      details: results,
      riskLevel: _riskLevel(results),
    );
  }

  static Future<bool> _checkGeolocator() async {
    try {
      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 10),
      );
      return pos.isMocked == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkNative(String method) async {
    try {
      final result = await _channel.invokeMethod<bool>(method);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkConsistency() async {
    try {
      final positions = <Position>[];
      for (int i = 0; i < 3; i++) {
        final pos = await Geolocator.getCurrentPosition().timeout(
          const Duration(seconds: 8),
        );
        positions.add(pos);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      for (int i = 1; i < positions.length; i++) {
        final dist = Geolocator.distanceBetween(
          positions[i - 1].latitude,
          positions[i - 1].longitude,
          positions[i].latitude,
          positions[i].longitude,
        );
        // Kecepatan di atas 500m dalam 0.6 detik = lonjakan teleportasi Fake GPS
        if (dist > 500) return true;
      }

      // Akurasi tidak wajar (sinyal sangat kabur atau disimulasikan buruk)
      if (positions.last.accuracy > 100) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  static String _riskLevel(Map<String, bool> r) {
    final count = r.values.where((v) => v).length;
    if (count == 0) return 'AMAN';
    if (count <= 1) return 'WASPADA';
    return 'BERBAHAYA';
  }
}

class MockLocationResult {
  final bool isMocked;
  final Map<String, bool> details;
  final String riskLevel;

  MockLocationResult({
    required this.isMocked,
    required this.details,
    required this.riskLevel,
  });

  String get userFriendlyMessage {
    if (details['mock_enabled'] == true || details['geolocator'] == true) {
      return 'Fitur Lokasi Tiruan (Mock Location / Fake GPS) terdeteksi aktif pada perangkat Anda. Matikan aplikasi Fake GPS untuk melanjutkan.';
    }
    if (details['mock_apps'] == true) {
      return 'Aplikasi Fake GPS terdeteksi terpasang pada HP Anda. Harap hapus (uninstall) aplikasi Fake GPS untuk melakukan absensi.';
    }
    if (details['device_rooted'] == true) {
      return 'Perangkat terdeteksi mengalami modifikasi sistem (Root). Demi keamanan dan keabsahan absensi, aplikasi tidak diizinkan pada perangkat yang di-root.';
    }
    if (details['emulator'] == true) {
      return 'Aplikasi dijalankan pada Emulator / Komputer. Absensi hanya dapat dilakukan melalui smartphone fisik.';
    }
    if (details['developer_mode'] == true) {
      return 'Opsi Pengembang (Developer Options) aktif pada HP Anda. Nonaktifkan Opsi Pengembang di Pengaturan HP Anda untuk melanjutkan absensi.';
    }
    if (details['consistency'] == true) {
      return 'Terdeteksi anomali pergerakan GPS (lonjakan koordinat tidak wajar). Pastikan Anda berada di luar ruangan dengan sinyal satelit GPS yang stabil.';
    }
    return 'Terdeteksi indikasi manipulasi lokasi palsu pada perangkat.';
  }
}
