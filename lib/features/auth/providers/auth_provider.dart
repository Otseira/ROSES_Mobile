import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiServiceProvider));
});

/// Data user dari cache lokal (cepat, untuk tampilan awal)
final authStateProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return await authService.getCurrentUser();
});

/// Data user TERBARU dari server (GET /me)
final freshProfileProvider = FutureProvider.autoDispose<UserModel?>((
  ref,
) async {
  try {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/me');

    final raw = response['data'];
    if (raw is Map<String, dynamic>) {
      final fresh = UserModel.fromJson(Map<String, dynamic>.from(raw));

      // Jika server tidak mengirim foto_profil, pertahankan foto dari cache
      if (fresh.fotoProfil == null) {
        final stored = await ref.read(authStateProvider.future);
        if (stored != null && stored.fotoProfil != null) {
          return UserModel(
            id: fresh.id,
            nik: fresh.nik,
            username: fresh.username,
            nama: fresh.nama,
            email: fresh.email,
            nomorWhatsapp: fresh.nomorWhatsapp,
            unitKerja: fresh.unitKerja ?? stored.unitKerja,
            role: fresh.role,
            fotoProfil: stored.fotoProfil,
            managesUnits: fresh.managesUnits,
          ); // ✅ canValidasi TIDAK dikirim — otomatis dihitung dari role
        }
      }

      return fresh;
    }
    return null;
  } catch (_) {
    return null;
  }
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref);
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState(isLoading: true)) {
    _init();
  }

  AuthService get _authService => _ref.read(authServiceProvider);

  /// ✅ AUTO-LOGIN: cek token di storage saat app dibuka
  Future<void> _init() async {
    try {
      final token = await StorageService.getToken();

      if (token == null || token.isEmpty) {
        // Tidak ada token → user belum login
        state = AuthState(isLoading: false);
        return;
      }

      // Token ada → validasi ke server
      final user = await _authService.getCurrentUser();

      if (user != null) {
        // Token valid → langsung masuk
        state = AuthState(user: user, isLoading: false);
      } else {
        // Token invalid/expired → hapus & ke login
        await StorageService.clearAll();
        state = AuthState(isLoading: false);
      }
    } catch (e) {
      // Error saat validasi (network issue, dll) → coba pakai cache
      final cachedUser = await StorageService.getUserData();
      if (cachedUser != null) {
        state = AuthState(
          user: UserModel.fromJson(cachedUser),
          isLoading: false,
        );
      } else {
        state = AuthState(isLoading: false);
      }
    }
  }

  Future<bool> login(String login, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(login, password);
      state = AuthState(user: user, isLoading: false);

      // Invalidate provider agar data user baru langsung ter-load
      _ref.invalidate(authStateProvider);
      _ref.invalidate(freshProfileProvider);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState(isLoading: false);

    // Invalidate semua provider yang menyimpan data user
    _ref.invalidate(authStateProvider);
    _ref.invalidate(freshProfileProvider);
  }
}
