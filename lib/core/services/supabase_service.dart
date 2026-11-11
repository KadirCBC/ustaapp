import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

// Kullanıcının anlık auth oturumu ve rolü için StateNotifierProvider
final authStateProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AuthNotifier(service);
});

class AppAuthState {
  final bool isLoading;
  final User? user;
  final UserRole? role;
  final String? errorMessage;
  final bool isDemo;

  const AppAuthState({
    this.isLoading = false,
    this.user,
    this.role,
    this.errorMessage,
    this.isDemo = false,
  });

  bool get isAuthenticated => user != null || isDemo;
  bool get hasSelectedRole => role != null;

  AppAuthState copyWith({
    bool? isLoading,
    User? user,
    UserRole? role,
    String? errorMessage,
    bool? isDemo,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      role: role ?? this.role,
      errorMessage: errorMessage,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final SupabaseService _service;
  StreamSubscription<AuthState>? _authSubscription;

  AuthNotifier(this._service) : super(const AppAuthState()) {
    _init();
  }

  void _init() {
    // Mevcut oturumu kontrol et
    final currentUser = _service.currentUser;
    if (currentUser != null) {
      _loadUserRole(currentUser);
    } else {
      state = state.copyWith(isLoading: false, user: null, role: null, isDemo: false);
    }

    // Oturum değişikliklerini dinle
    _authSubscription = _service.authStateChanges.listen((event) async {
      final user = event.session?.user;
      if (user != null) {
        await _loadUserRole(user);
      } else {
        if (!state.isDemo) {
          state = state.copyWith(isLoading: false, user: null, role: null);
        }
      }
    });
  }

  Future<void> _loadUserRole(User user) async {
    state = state.copyWith(isLoading: true, user: user);
    try {
      final role = await _service.fetchUserRole(user.id);
      state = state.copyWith(isLoading: false, user: user, role: role);
    } catch (e) {
      debugPrint('Rol yüklenirken hata: $e');
      state = state.copyWith(isLoading: false, user: user, role: null);
    }
  }

  Future<void> refreshProfile() async {
    if (state.user != null) {
      await _loadUserRole(state.user!);
    }
  }

  void setRole(UserRole role) {
    state = state.copyWith(role: role, isDemo: true, isLoading: false);
  }

  void setDemoSession(UserRole role) {
    state = state.copyWith(
      role: role,
      isDemo: true,
      isLoading: false,
    );
  }

  Future<void> signOut() async {
    state = const AppAuthState(isLoading: false, user: null, role: null, isDemo: false);
    await _service.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Kullanıcı ID'sine göre 'profiles' tablosundan rolü çeker
  Future<UserRole?> fetchUserRole(String userId) async {
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['role'] == null) {
        return null;
      }

      return UserRole.fromDbValue(response['role'] as String);
    } catch (e) {
      debugPrint('Supabase fetchUserRole hatası: $e');
      return null;
    }
  }

  /// Telefon numarasına SMS OTP gönderir
  Future<void> sendOtp(String e164Phone) async {
    await _client.auth.signInWithOtp(
      phone: e164Phone,
      channel: OtpChannel.sms,
    );
  }

  /// SMS OTP kodunu doğrular
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );
    return response;
  }

  /// Yeni kayıt olan kullanıcı için profil ve rol kaydını tamamlar
  Future<void> completeProfileAndRole({
    required String userId,
    required String phone,
    required UserRole role,
    required String fullName,
  }) async {
    // 1. profiles tablosuna ekle / güncelle
    await _client.from(AppConstants.profilesTable).upsert({
      'id': userId,
      'phone': phone,
      'role': role.toDbValue(),
      'full_name': fullName,
    });

    // 2. Eğer usta ise ustalar tablosuna taslak satır ekle
    if (role == UserRole.usta) {
      await _client.from(AppConstants.ustalarTable).upsert({
        'id': userId,
        'kategori': 'elektrik', // Varsayılan başlangıç kategorisi
        'konum': 'SRID=4326;POINT(28.9784 41.0082)', // Varsayılan İstanbul merkezi
        'is_online': false,
        'servis_ucreti': 500.00,
        'puan': 5.00,
      });
    }
  }

  /// Oturumu kapat
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
