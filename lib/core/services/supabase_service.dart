import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
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
  final appDataService = ref.watch(appDataServiceProvider);
  return AuthNotifier(service, appDataService);
});

class AppAuthState {
  final bool isLoading;
  final User? user;
  final UserRole? role;
  final String? errorMessage;
  final bool isDemo;
  final String? phone;
  final String? fullName;

  const AppAuthState({
    this.isLoading = true,
    this.user,
    this.role,
    this.errorMessage,
    this.isDemo = false,
    this.phone,
    this.fullName,
  });

  bool get isAuthenticated => (user != null || isDemo) && role != null;
  bool get hasSelectedRole => role != null;

  AppAuthState copyWith({
    bool? isLoading,
    User? user,
    UserRole? role,
    String? errorMessage,
    bool? isDemo,
    String? phone,
    String? fullName,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      role: role ?? this.role,
      errorMessage: errorMessage,
      isDemo: isDemo ?? this.isDemo,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
    );
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final SupabaseService _service;
  final AppDataService _appDataService;
  StreamSubscription<AuthState>? _authSubscription;

  AuthNotifier(this._service, this._appDataService) : super(const AppAuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    // 1. Önce cihazda/tarayıcıda saklanan aktif oturumu kontrol et (F5 ve uygulama yeniden açılışları)
    try {
      final activeSession = await _appDataService.getActiveSession();
      if (activeSession != null) {
        final roleStr = activeSession['role'] as String?;
        final role = roleStr != null ? UserRole.fromDbValue(roleStr) : null;
        if (role != null) {
          state = state.copyWith(
            isLoading: false,
            isDemo: true,
            role: role,
            phone: activeSession['phone'] as String?,
            fullName: activeSession['full_name'] as String?,
          );
          debugPrint(
            '>>> [AuthNotifier] Aktif oturum geri yüklendi: phone=${state.phone}, name=${state.fullName}, role=${state.role}',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Aktif oturum geri yüklenirken hata: $e');
    }

    // 2. Supabase oturumunu kontrol et
    final currentUser = _service.currentUser;
    if (currentUser != null) {
      await _loadUserRole(currentUser);
    } else {
      state = state.copyWith(isLoading: false, user: null, role: null, isDemo: false);
    }

    // 3. Supabase oturum değişikliklerini dinle
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

  void setAuthenticatedSession({
    required UserRole role,
    required String phone,
    required String fullName,
  }) {
    state = state.copyWith(
      role: role,
      phone: phone,
      fullName: fullName,
      isDemo: true,
      isLoading: false,
    );
    _appDataService.saveActiveSession(
      phone: phone,
      fullName: fullName,
      role: role.toDbValue(),
    );
  }

  void setRole(UserRole role, {String? phone, String? fullName}) {
    final effectivePhone = phone ?? state.phone ?? (role == UserRole.usta ? '5524342069' : '5329998877');
    final effectiveName = fullName ?? state.fullName ?? (role == UserRole.usta ? 'Kadir Usta' : 'Ahmet Demir');
    setAuthenticatedSession(
      role: role,
      phone: effectivePhone,
      fullName: effectiveName,
    );
  }

  void setDemoSession(UserRole role) {
    setRole(role);
  }

  Future<void> signOut() async {
    state = const AppAuthState(isLoading: false, user: null, role: null, isDemo: false);
    await _appDataService.clearActiveSession();
    try {
      await _service.signOut();
    } catch (_) {}
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
