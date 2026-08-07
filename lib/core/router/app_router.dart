import 'package:bus_ticketing/features/auth/login/login_page.dart';
import 'package:bus_ticketing/features/auth/phone/otp_verification_page.dart';
import 'package:bus_ticketing/features/auth/register/sign_up_page.dart';
import 'package:bus_ticketing/features/auth/register/verify_email_page.dart';
import 'package:bus_ticketing/features/bus_search/models/booking_data.dart';
import 'package:bus_ticketing/features/bus_search/models/bus_model.dart';
import 'package:bus_ticketing/features/bus_search/models/bus_search_params.dart';
import 'package:bus_ticketing/features/bus_search/pages/booking_confirmed_page.dart';
import 'package:bus_ticketing/features/bus_search/pages/bus_results_page.dart';
import 'package:bus_ticketing/features/bus_search/pages/payment_page.dart';
import 'package:bus_ticketing/features/bus_search/pages/paystack_webview_page.dart';
import 'package:bus_ticketing/features/bus_search/pages/payment_processing_page.dart';
import 'package:bus_ticketing/features/bus_search/pages/seat_selection_page.dart';
import 'package:bus_ticketing/features/home/pages/home_page.dart';
import 'package:bus_ticketing/features/main_shell/main_shell.dart';
import 'package:bus_ticketing/features/profile/pages/profile_page.dart';
import 'package:bus_ticketing/features/search/pages/search_page.dart';
import 'package:bus_ticketing/features/tickets/pages/tickets_page.dart';
import 'package:bus_ticketing/features/tickets/pages/booking_details_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/register/set_password_page.dart';
import '../../features/driver_dashboard/pages/driver_dashboard_page.dart';
import '../../features/driver_dashboard/pages/driver_shell.dart';
import '../../features/driver_dashboard/pages/driver_scan_page.dart';
import '../../features/driver_dashboard/pages/driver_tickets_page.dart';
import '../../features/driver_dashboard/pages/driver_settings_page.dart';
import '../../features/reviews/pages/submit_complaint_page.dart';
import '../../features/reviews/pages/submit_rating_page.dart';
import '../../features/reviews/pages/my_reviews_page.dart';
import '../../features/driver_dashboard/pages/submit_driver_report_page.dart';
import '../../features/driver_dashboard/pages/my_driver_reports_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/reset_otp_page.dart';
import '../../features/auth/pages/new_password_page.dart';
import '../../features/bus_tracking/pages/bus_tracking_page.dart';
import '../../features/auth/pages/account_deactivated_page.dart';

// ─── Route path constants ─────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const otpVerification = '/otp-verification';
  static const driverDashboard = '/driver/home';
  static const driverScan = '/driver/scan';
  static const driverTickets = '/driver/tickets';
  static const driverSettings = '/driver/settings';
  static const acceptInvite = '/accept-invite';

  // Reviews
  static const submitComplaint = '/submit-complaint';
  static const submitRating = '/submit-rating';
  static const myReviews = '/my-reviews';

  // Driver reports
  static const submitDriverReport = '/driver/report/submit';
  static const myDriverReports = '/driver/report/list';

  // Password reset
  static const forgotPassword = '/forgot-password';
  static const resetOtp = '/reset-otp';
  static const newPassword = '/new-password';

  // Bus tracking
  static const busTracking = '/bus-tracking/:tripId';

  // Account deactivated
  static const deactivated = '/deactivated';

  // Booking flow (outside shell — no bottom nav)
  static const busResults = '/bus-results';
  static const seatSelection = '/seat-selection';
  static const payment = '/payment';
  static const paystackWebview = '/paystack-webview';
  static const paymentProcessing = '/payment-processing';
  static const bookingConfirmed = '/booking-confirmed';
  static const bookingDetails = '/booking-details/:id';

  // Shell branches
  static const home = '/home';
  static const tickets = '/tickets';
  static const search = '/search';
  static const profile = '/profile';
}

// ─── Router ───────────────────────────────────────────────────────────────────

bool hasSplashed = false;
String? targetPathAfterSplash;

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  redirect: (context, state) {
    final path = state.uri.path;
    if (!hasSplashed) {
      if (path == AppRoutes.splash || path == AppRoutes.acceptInvite) {
        return null;
      }
      targetPathAfterSplash = state.uri.toString();
      return AppRoutes.splash;
    }
    return null;
  },
  routes: [
    // ── Auth + splash ──────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      pageBuilder: (context, state) => _noTransitionPage(
        state: state,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      pageBuilder: (context, state) => _fadePage(
        state: state,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      pageBuilder: (context, state) => _noTransitionPage(
        state: state,
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.signUp,
      name: 'sign-up',
      pageBuilder: (context, state) => _noTransitionPage(
        state: state,
        child: const SignUpPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      name: 'verify-email',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: VerifyEmailPage(email: state.extra as String),
      ),
    ),
    GoRoute(
      path: AppRoutes.otpVerification,
      name: 'otp-verification',
      pageBuilder: (context, state) {
        final phoneNumber = state.extra as String? ?? '';
        return _noTransitionPage(
          state: state,
          child: OTPVerificationPage(phoneNumber: phoneNumber),
        );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          DriverShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.driverDashboard,
              name: 'driver-dashboard',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const DriverDashboardPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.driverScan,
              name: 'driver-scan',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const DriverScanPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.driverTickets,
              name: 'driver-tickets',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const DriverTicketsPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.driverSettings,
              name: 'driver-settings',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const DriverSettingsPage(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.acceptInvite,
      name: 'accept-invite',
      pageBuilder: (context, state) {
        final inviteToken = state.uri.queryParameters['token'] ?? '';
        return _noTransitionPage(
          state: state,
          child: SetPasswordPage(inviteToken: inviteToken),
        );
      },
    ),

    // ── Booking flow (no bottom nav) ───────────────────────────────────────
    GoRoute(
      path: AppRoutes.busResults,
      name: 'bus-results',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: BusResultsPage(params: state.extra as BusSearchParams),
      ),
    ),
    GoRoute(
      path: AppRoutes.seatSelection,
      name: 'seat-selection',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _slidePage(
          state: state,
          child: SeatSelectionPage(
            bus: extra['bus'] as BusModel,
            params: extra['params'] as BusSearchParams,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.payment,
      name: 'payment',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: PaymentPage(data: state.extra as BookingData),
      ),
    ),
    GoRoute(
      path: AppRoutes.paystackWebview,
      name: 'paystack-webview',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: PaystackWebviewPage(data: state.extra as BookingData),
      ),
    ),
    GoRoute(
      path: AppRoutes.paymentProcessing,
      name: 'payment-processing',
      pageBuilder: (context, state) => _fadePage(
        state: state,
        child: PaymentProcessingPage(data: state.extra as BookingData),
      ),
    ),
    GoRoute(
      path: AppRoutes.bookingConfirmed,
      name: 'booking-confirmed',
      pageBuilder: (context, state) => _fadePage(
        state: state,
        child: BookingConfirmedPage(data: state.extra as BookingData),
      ),
    ),
    GoRoute(
      path: AppRoutes.bookingDetails,
      name: 'booking-details',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: BookingDetailsPage(
          bookingId: state.pathParameters['id']!,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.submitComplaint,
      name: 'submit-complaint',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _slidePage(
          state: state,
          child: SubmitComplaintPage(
            tripId: extra['tripId'] as String,
            tripOrigin: extra['tripOrigin'] as String,
            tripDestination: extra['tripDestination'] as String,
            departureTime: extra['departureTime'] as DateTime?,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.submitRating,
      name: 'submit-rating',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _slidePage(
          state: state,
          child: SubmitRatingPage(
            tripId: extra['tripId'] as String,
            tripOrigin: extra['tripOrigin'] as String,
            tripDestination: extra['tripDestination'] as String,
            driverName: extra['driverName'] as String?,
            departureTime: extra['departureTime'] as DateTime?,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.myReviews,
      name: 'my-reviews',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: const MyReviewsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.submitDriverReport,
      name: 'submit-driver-report',
      pageBuilder: (context, state) {
        final trip = state.extra as dynamic;
        return _slidePage(
          state: state,
          child: SubmitDriverReportPage(preselectedTrip: trip),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.myDriverReports,
      name: 'my-driver-reports',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: const MyDriverReportsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgot-password',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: const ForgotPasswordPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.resetOtp,
      name: 'reset-otp',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: ResetOtpPage(email: state.extra as String),
      ),
    ),
    GoRoute(
      path: AppRoutes.newPassword,
      name: 'new-password',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: NewPasswordPage(resetToken: state.extra as String),
      ),
    ),

    GoRoute(
      path: AppRoutes.busTracking,
      name: 'bus-tracking',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: BusTrackingPage(
          tripId: state.pathParameters['tripId']!,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.deactivated,
      name: 'deactivated',
      pageBuilder: (context, state) => _fadePage(
        state: state,
        child: const AccountDeactivatedPage(),
      ),
    ),

    // ── Shell (bottom nav) ─────────────────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const HomePage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.tickets,
              name: 'tickets',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const TicketsPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.search,
              name: 'search',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const SearchPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              pageBuilder: (context, state) => _noTransitionPage(
                state: state,
                child: const ProfilePage(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

// ─── Page builders ────────────────────────────────────────────────────────────

CustomTransitionPage<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    transitionsBuilder: (_, _, _, c) => c,
  );
}

CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage<void> _slidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: animation.drive(
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut)),
      ),
      child: child,
    ),
  );
}
