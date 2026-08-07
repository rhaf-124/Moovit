import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/connectivity_cubit.dart';
import 'core/network/dio_client.dart';
import 'core/notifications/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_manager.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/theme.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/bus_search/data/datasources/booking_remote_datasource.dart';
import 'features/bus_search/data/datasources/trip_remote_datasource.dart';
import 'features/bus_search/data/repositories/booking_repository_impl.dart';
import 'features/bus_search/data/repositories/trip_repository_impl.dart';
import 'features/bus_search/domain/repositories/booking_repository.dart';
import 'features/bus_search/domain/repositories/trip_repository.dart';
import 'features/driver_dashboard/data/datasources/driver_remote_datasource.dart';
import 'features/driver_dashboard/data/repositories/driver_repository_impl.dart';
import 'features/driver_dashboard/domain/repositories/driver_repository.dart';
import 'features/reviews/data/datasources/review_remote_datasource.dart';
import 'features/reviews/data/repositories/review_repository_impl.dart';
import 'features/reviews/domain/repositories/review_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialized before anything else that touches FCM.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();
  final initialTheme = loadSavedThemeMode(prefs);

  final tokenStorage = TokenStorage();
  final dioClient = DioClient();
  final remoteDataSource = AuthRemoteDataSource(dioClient.dio);
  final authRepository = AuthRepositoryImpl(remoteDataSource, tokenStorage);

  final tripRemoteDataSource = TripRemoteDataSource(dioClient.dio);
  final tripRepository = TripRepositoryImpl(tripRemoteDataSource);

  final bookingRemoteDataSource = BookingRemoteDataSource(dioClient.dio);
  final bookingRepository = BookingRepositoryImpl(bookingRemoteDataSource);

  final driverRemoteDataSource = DriverRemoteDataSource(dioClient.dio);
  final driverRepository = DriverRepositoryImpl(driverRemoteDataSource);

  final reviewRemoteDataSource = ReviewRemoteDataSource(dioClient.dio);
  final reviewRepository = ReviewRepositoryImpl(reviewRemoteDataSource);

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (_) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<TripRepository>.value(value: tripRepository),
        RepositoryProvider<BookingRepository>.value(value: bookingRepository),
        RepositoryProvider<DriverRepository>.value(value: driverRepository),
        RepositoryProvider<ReviewRepository>.value(value: reviewRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeBloc(prefs, initial: initialTheme)),
          BlocProvider(create: (_) => ConnectivityCubit()),
          BlocProvider(
            create: (_) => AuthCubit(authRepository, tokenStorage),
          ),
        ],
        child: const MoovitApp(),
      ),
    ),
    ),
  );
}

class MoovitApp extends StatefulWidget {
  const MoovitApp({super.key});

  @override
  State<MoovitApp> createState() => _MoovitAppState();
}

class _MoovitAppState extends State<MoovitApp> {
  StreamSubscription<void>? _deactivatedSub;

  @override
  void initState() {
    super.initState();

    // When DioClient detects "account inactive" from the server, force the
    // AuthCubit into AuthDeactivated and navigate to the deactivated screen.
    _deactivatedSub = DioClient.onAccountDeactivated.listen((_) {
      if (mounted) {
        context.read<AuthCubit>().forceDeactivated();
      }
    });

    final dlm = DeepLinkManager.instance;
    dlm.onLinkReceived = (uri) {
      debugPrint('Deep Link received in MoovitApp: $uri');
      if (uri.path == '/accept-invite') {
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          appRouter.go('${AppRoutes.acceptInvite}?token=$token');
        }
      }
    };

    // Defer until after the first frame so the router & widget tree are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      dlm.initDeepLinks();
      _handleColdStart();
    });
  }

  /// If the app was launched by tapping an FCM notification while terminated,
  /// getInitialMessage() returns it so we can navigate to the right screen.
  Future<void> _handleColdStart() async {
    final message = await FcmService.instance.getInitialMessage();
    if (message != null) {
      FcmService.navigate(message.data);
    }
  }

  @override
  void dispose() {
    _deactivatedSub?.cancel();
    DeepLinkManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthDeactivated) {
          appRouter.go(AppRoutes.deactivated);
        }
      },
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'VIPGo',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            routerConfig: appRouter,
            locale: DevicePreview.locale(context),
            builder: (context, child) => DevicePreview.appBuilder(
              context,
              _ConnectivityOverlay(child: child!),
            ),
          );
        },
      ),
    );
  }
}

class _ConnectivityOverlay extends StatelessWidget {
  const _ConnectivityOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityStatus>(
      builder: (context, status) {
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: status == ConnectivityStatus.offline ? null : 0,
              child: status == ConnectivityStatus.offline
                  ? Material(
                      color: Colors.red.shade700,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.wifi_off,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'No internet connection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
