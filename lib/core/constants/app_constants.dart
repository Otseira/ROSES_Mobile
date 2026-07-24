class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'https://absensi.ropanasuri.com/api';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // GPS
  static const double defaultHospitalLat = -0.9471;
  static const double defaultHospitalLng = 100.3511;
  static const int defaultRadiusMeter = 50;
  static const double maxGpsAccuracy = 50.0; // meter

  // Camera
  static const int maxPhotoSizeKB = 2048; // 2MB
  static const int compressQuality = 80;

  // App Info
  static const String appName = 'SIRO';
  static const String appVersion = '1.0.0';
}
