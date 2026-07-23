import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
  }

  // User Data
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    await _storage.write(key: AppConstants.userKey, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final data = await _storage.read(key: AppConstants.userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  static Future<void> deleteUserData() async {
    await _storage.delete(key: AppConstants.userKey);
  }

  // Clear All
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
