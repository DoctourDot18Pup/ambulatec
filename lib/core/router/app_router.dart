import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/auth/data/user_provider.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/role_select_page.dart';
import '../../features/vendor/presentation/vendor_verify_page.dart';
import '../../features/feed/presentation/home_page.dart';
import '../../features/feed/presentation/vendors_page.dart';
import '../../features/vendor/presentation/dashboard_page.dart';
import '../../features/feed/presentation/post_detail_page.dart';
import '../../features/vendor/presentation/create_post_page.dart';
import '../../features/orders/presentation/order_summary_page.dart';
import '../../features/orders/presentation/payment_page.dart';
import '../../features/orders/presentation/order_confirmed_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/orders/presentation/order_alert_page.dart';
import '../../features/orders/presentation/review_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/feed/presentation/search_page.dart';
import '../../features/vendor/presentation/earnings_page.dart';
import '../../features/profile/presentation/vendor_profile_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/profile/presentation/my_reviews_page.dart';

// ── Router notifier ────────────────────────────────────────────────────────

/// [ChangeNotifier] that drives [GoRouter]'s reactive redirect.
///
/// Listens to [authStateProvider] and [userProvider] so the router
/// re-evaluates its redirect whenever auth state or user data changes.
/// Also persists and reads the `onboarding_seen` flag via [SharedPreferences].
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _onboardingSeen = false;
  bool _initialized = false;

  RouterNotifier(this._ref) {
    _init();
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(userProvider, (_, _) => notifyListeners());
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    _initialized = true;
    notifyListeners();
  }

  /// Marks the onboarding as seen and persists the flag.
  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    _onboardingSeen = true;
    notifyListeners();
  }

  // ── Redirect logic ─────────────────────────────────────────────────────────

  String? redirect(BuildContext context, GoRouterState state) {
    // Do not redirect while [SharedPreferences] is loading.
    if (!_initialized) return null;

    final firebaseUser = _ref.read(authStateProvider).asData?.value;
    final userModel = _ref.read(userProvider).asData?.value;
    final loc = state.matchedLocation;

    // ── Unauthenticated ──────────────────────────────────────────────────────
    if (firebaseUser == null) {
      if (loc == '/onboarding' || loc == '/login') return null;
      return _onboardingSeen ? '/login' : '/onboarding';
    }

    // ── Authenticated — waiting for Firestore data ───────────────────────────
    if (userModel == null) {
      if (loc == '/role-select') return null;
      return null; // Stay while loading.
    }

    // ── Authenticated — block access to public routes ────────────────────────
    if (loc == '/onboarding' || loc == '/login') {
      return _resolveAuthenticatedRoute(userModel);
    }

    // ── Role selection required ──────────────────────────────────────────────
    if (userModel.roles.isEmpty) {
      if (loc == '/role-select') return null;
      return '/role-select';
    }

    // ── Vendor verification pending ──────────────────────────────────────────
    final needsVerify = userModel.roles.contains('vendor') &&
        userModel.vendorStatus == VendorStatus.pending;
    if (needsVerify) {
      if (loc == '/vendor-verify') return null;
      return '/vendor-verify';
    }

    // ── Admin guard ──────────────────────────────────────────────────────────
    if (loc == '/admin') {
      if (userModel.isAdmin != true) return '/home';
    }

    // ── All checks passed ────────────────────────────────────────────────────
    return null;
  }

  String _resolveAuthenticatedRoute(UserModel user) {
    if (user.roles.isEmpty) return '/role-select';
    if (user.roles.contains('vendor') &&
        user.vendorStatus == VendorStatus.pending) {
      return '/vendor-verify';
    }
    if (user.roles.contains('vendor') &&
        user.vendorStatus == VendorStatus.approved) {
      return '/dashboard';
    }
    return '/home';
  }
}

// ── Providers ──────────────────────────────────────────────────────────────


final routerNotifierProvider =
    ChangeNotifierProvider<RouterNotifier>((ref) => RouterNotifier(ref));
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(routerNotifierProvider);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        redirect: (_, _) => '/onboarding',
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/role-select',
        name: 'roleSelect',
        builder: (context, state) => const RoleSelectPage(),
      ),
      GoRoute(
        path: '/vendor-verify',
        name: 'vendorVerify',
        builder: (context, state) => const VendorVerifyPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/vendors',
        name: 'vendors',
        builder: (context, state) => const VendorsPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/post/:postId',
        name: 'postDetail',
        builder: (context, state) => PostDetailPage(
          postId: state.pathParameters['postId']!,
        ),
      ),
      GoRoute(
        path: '/order-summary',
        name: 'orderSummary',
        builder: (context, state) => const OrderSummaryPage(),
      ),
      GoRoute(
        path: '/create-post',
        name: 'createPost',
        builder: (context, state) => const CreatePostPage(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) => const OrdersPage(),
      ),
      GoRoute(
        path: '/earnings',
        name: 'earnings',
        builder: (context, state) => const EarningsPage(),
      ),
      GoRoute(
        path: '/vendor/:vendorId',
        name: 'vendorProfile',
        builder: (context, state) => VendorProfilePage(
          vendorId: state.pathParameters['vendorId']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/review/:orderId',
        name: 'review',
        builder: (context, state) => ReviewPage(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPage(),
      ),
      GoRoute(
        path: '/payment',
        name: 'payment',
        builder: (context, state) => const PaymentPage(),
      ),
      GoRoute(
        path: '/order-confirmed',
        name: 'orderConfirmed',
        builder: (context, state) => const OrderConfirmedPage(),
      ),
      GoRoute(
        path: '/chat/:orderId',
        name: 'chat',
        builder: (context, state) => ChatPage(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '/order-alert/:orderId',
        name: 'orderAlert',
        builder: (context, state) => OrderAlertPage(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '/order-detail/:orderId',
        name: 'orderDetail',
        builder: (context, state) => OrderDetailPage(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '/my-reviews',
        name: 'myReviews',
        builder: (context, state) => const MyReviewsPage(),
      ),
    ],
  );
});

