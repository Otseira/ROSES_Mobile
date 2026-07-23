import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiServiceProvider));
});

final authStateProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return await authService.getCurrentUser();
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
