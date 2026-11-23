import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/admin/views/admin_dashboard_screen.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/auth/views/phone_auth_screen.dart';
import 'package:ustaapp/features/home/views/customer_home_screen.dart';
import 'package:ustaapp/features/map/views/customer_map_screen.dart';
import 'package:ustaapp/features/orders/views/customer_active_call_screen.dart';
import 'package:ustaapp/features/orders/views/customer_on_the_way_screen.dart';
import 'package:ustaapp/features/orders/views/customer_summary_rating_screen.dart';
import 'package:ustaapp/features/orders/views/incoming_call_screen.dart';
import 'package:ustaapp/features/orders/views/usta_active_job_screen.dart';
import 'package:ustaapp/features/orders/views/usta_orders_screen.dart';
import 'package:ustaapp/features/orders/views/usta_wallet_screen.dart';
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

final rootNavigatorKey = GlobalKey<NavigatorState>();
GoRouter? globalGoRouter;

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(appRouterNotifierProvider);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);

      // Kilit ekranında veya arka plandan gelen çağrı her durumda engelsiz açılsın
      if (state.matchedLocation.startsWith('/usta/incoming-call')) {
        return null;
      }

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
          return '/customer/home';
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
        path: '/customer/home',
        name: 'customerHome',
        builder: (context, state) => const CustomerHomeScreen(),
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
        path: '/usta/incoming-call/:cagriId',
        name: 'ustaIncomingCall',
        builder: (context, state) {
          final cagriId = state.pathParameters['cagriId'] ?? '';
          return IncomingCallScreen(cagriId: cagriId);
        },
      ),
      GoRoute(
        path: '/usta/wallet',
        name: 'ustaWallet',
        builder: (context, state) => const UstaWalletScreen(),
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
  globalGoRouter = router;
  return router;
});
