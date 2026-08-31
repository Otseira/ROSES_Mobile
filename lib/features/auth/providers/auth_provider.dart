import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
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

  AuthNotifier(this._ref) : super(AuthState());

  AuthService get _authService => _ref.read(authServiceProvider);

  Future<bool> login(String login, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(login, password);
      state = AuthState(user: user, isLoading: false);

      // ✅ Invalidate provider agar data user baru langsung ter-load
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
    state = AuthState();

    // ✅ FIX UTAMA: Invalidate SEMUA provider yang menyimpan data user
    //    Ini memastikan cache provider terbuang → akun baru pasti fetch data baru
    _ref.invalidate(authStateProvider);
    _ref.invalidate(freshProfileProvider);

    // TODO: Tambahkan invalidate untuk provider lain jika ada
    // _ref.invalidate(absensiStatusProvider);
    // _ref.invalidate(jadwalDinasProvider);
    // dll...
  }
}
