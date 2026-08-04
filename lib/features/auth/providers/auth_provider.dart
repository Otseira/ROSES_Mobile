import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiServiceProvider));
});

/// Data user dari cache lokal (cepat, untuk tampilan awal)
final authStateProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return await authService.getCurrentUser();
});

/// ✅ BARU: Data user TERBARU dari server (GET /me)
/// Agar setiap perubahan profil langsung terlihat di halaman Profil
final freshProfileProvider = FutureProvider<UserModel?>((ref) async {
  try {
    final api = ref.read(apiServiceProvider);
    final response = await api.get('/me');

    if (response is Map && response['data'] is Map) {
      final fresh = UserModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );

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
          );
        }
      }

      return fresh;
    }
    return null;
  } catch (_) {
    // Gagal ambil data terbaru (mis. offline) → tampilan tetap pakai cache
    return null;
  }
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.read(authServiceProvider));
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
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState());

  Future<bool> login(String login, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(login, password);
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState();
  }
}
