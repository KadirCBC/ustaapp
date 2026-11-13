import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/admin/views/admin_dashboard_screen.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/auth/views/phone_auth_screen.dart';
import 'package:ustaapp/features/map/views/customer_map_screen.dart';
import 'package:ustaapp/features/orders/views/customer_active_call_screen.dart';
import 'package:ustaapp/features/orders/views/customer_on_the_way_screen.dart';
import 'package:ustaapp/features/orders/views/customer_summary_rating_screen.dart';
import 'package:ustaapp/features/orders/views/usta_active_job_screen.dart';
import 'package:ustaapp/features/orders/views/usta_orders_screen.dart';
import 'package:ustaapp/features/profile/views/profile_screen.dart';
import 'package:ustaapp/features/splash/views/splash_screen.dart';

class AppRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  AppRouterNotifier(this._ref) {
    _ref.listen<AppAuthState>(authStateProvider, (_, __) => notifyListeners());
  }
}

final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  return AppRouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(appRouterNotifierProvider);

  return GoRouter(
    initialLocation: kIsWeb ? '/admin' : '/splash',
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);

      final isSplash = state.matchedLocation == '/splash';
      if (isSplash) return null;

      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      // Admin dashboard web erişimi için bağımsız güvenlik denetimine sahiptir
      if (isAdminRoute) return null;

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
        path: '/admin',
        name: 'adminDashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
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
        path: '/customer/active-call/:cagriId',
        name: 'customerActiveCall',
        builder: (context, state) {
          final cagriId = state.pathParameters['cagriId'] ?? '';
          return CustomerActiveCallScreen(cagriId: cagriId);
        },
      ),
      GoRoute(
        path: '/customer/on-the-way/:cagriId',
        name: 'customerOnTheWay',
        builder: (context, state) {
          final cagriId = state.pathParameters['cagriId'] ?? '';
          return CustomerOnTheWayScreen(cagriId: cagriId);
        },
      ),
      GoRoute(
        path: '/customer/summary/:cagriId',
        name: 'customerSummary',
        builder: (context, state) {
          final cagriId = state.pathParameters['cagriId'] ?? '';
          return CustomerSummaryRatingScreen(cagriId: cagriId);
        },
      ),
      GoRoute(
        path: '/usta/orders',
        name: 'ustaOrders',
        builder: (context, state) => const UstaOrdersScreen(),
      ),
      GoRoute(
        path: '/usta/active-job/:cagriId',
        name: 'ustaActiveJob',
        builder: (context, state) {
          final cagriId = state.pathParameters['cagriId'] ?? '';
          return UstaActiveJobScreen(cagriId: cagriId);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
