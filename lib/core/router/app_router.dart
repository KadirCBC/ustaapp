import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/auth/views/phone_auth_screen.dart';
import 'package:ustaapp/features/map/views/customer_map_screen.dart';
import 'package:ustaapp/features/orders/views/usta_orders_screen.dart';
import 'package:ustaapp/features/profile/views/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/auth',
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthRoute = state.matchedLocation == '/auth';

      // 1. Henüz oturum durumu yükleniyorsa yönlendirme yapma
      if (authState.isLoading) {
        return null;
      }

      // 2. Kullanıcı giriş yapmamışsa sadece /auth ekranına izin ver
      if (!authState.isAuthenticated) {
        return isAuthRoute ? null : '/auth';
      }

      // 3. Kullanıcı giriş yapmış fakat henüz bir rol seçmemişse /auth (rol seçimi adımı) ekranında kalsın
      if (authState.role == null) {
        return isAuthRoute ? null : '/auth';
      }

      // 4. Kullanıcı giriş yapmış ve rolü belirlenmişken /auth'a girmeye çalışırsa rolüne göre ana ekrana yönlendir
      if (isAuthRoute) {
        if (authState.role == UserRole.usta) {
          return '/usta/orders';
        } else {
          return '/customer/map';
        }
      }

      // 5. Normal navigasyona izin ver
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const PhoneAuthScreen(),
      ),
      GoRoute(
        path: '/customer/map',
        name: 'customerMap',
        builder: (context, state) => const CustomerMapScreen(),
      ),
      GoRoute(
        path: '/usta/orders',
        name: 'ustaOrders',
        builder: (context, state) => const UstaOrdersScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
