import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../../features/auth/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiServiceProvider));
});

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<UserModel> login(String login, String password) async {
    final response = await _api.post(
      '/login',
      data: {'login': login, 'password': password},
    );

    // 1. Cek sukses
    if (response['success'] != true) {
      throw Exception(response['message']?.toString() ?? 'Login gagal.');
    }

    // 2. Ambil & simpan token (dukung 'access_token' maupun 'token')
    final token =
        response['access_token']?.toString() ?? response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak diterima dari server.');
    }
    await StorageService.saveToken(token);

    // 3. Ambil data user — backend SIRO mengirimnya di key 'data'
    //    (defensif: cek 'data' dulu, lalu 'user', agar tidak crash bila struktur berubah)
    Map<String, dynamic>? userData;
    final rawData = response['data'];
    final rawUser = response['user'];
    if (rawData is Map<String, dynamic>) {
      userData = rawData;
    } else if (rawUser is Map<String, dynamic>) {
      userData = rawUser;
    }

    UserModel user;
    if (userData != null) {
      user = UserModel.fromJson(userData);
      await StorageService.saveUserData(userData);
    } else {
      // 4. Fallback: bila response login tidak memuat user, ambil via /me
      //    (token sudah tersimpan, jadi /me bisa dipanggil)
      final me = await getCurrentUser();
      if (me == null) {
        throw Exception('Gagal memuat data profil setelah login.');
      }
      user = me;
    }

    return user;
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await StorageService.getToken();
    if (token == null) return null;

    try {
      final response = await _api.get('/me');
      if (response['success'] == true) {
        // defensif: pastikan 'data' benar-benar Map sebelum cast
        final raw = response['data'];
        if (raw is Map<String, dynamic>) {
          await StorageService.saveUserData(raw);
          return UserModel.fromJson(raw);
        }
      }
    } catch (_) {
      await StorageService.clearAll();
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } catch (_) {
      // abaikan error server, tetap bersihkan data lokal
    }
    await StorageService.clearAll();
  }
}
