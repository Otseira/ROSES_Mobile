import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class MockLocationDetector {
  static const _channel = MethodChannel('com.siro/mock_detection');

  static Future<MockLocationResult> detect() async {
    final results = <String, bool>{};

    // Layer 1: Geolocator built-in
    results['geolocator'] = await _checkGeolocator();

    // Layer 2: Native Android checks
    if (Platform.isAndroid) {
      results['developer_mode'] = await _checkNative(
        'isDeveloperOptionsEnabled',
      );
      results['mock_apps'] = await _checkNative('isMockLocationAppInstalled');
      results['mock_enabled'] = await _checkNative('isMockLocationEnabled');
    }

    // Layer 3: Location consistency
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
      // ✅ getCurrentPosition() tanpa named param (kompatibel semua versi)
      // ✅ .timeout() menggantikan timeLimit
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
        // ✅ tanpa named param + timeout per sampel
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
        if (dist > 500) return true; // Teleport detected
      }

      if (positions.last.accuracy > 100) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  static String _riskLevel(Map<String, bool> r) {
    final count = r.values.where((v) => v).length;
    if (count == 0) return 'AMAN';
    if (count <= 2) return 'WASPADA';
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
}
