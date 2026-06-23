// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bus_ticketing/core/network/connectivity_cubit.dart';
import 'package:bus_ticketing/core/network/dio_client.dart';
import 'package:bus_ticketing/core/storage/token_storage.dart';
import 'package:bus_ticketing/core/theme/theme.dart';
import 'package:bus_ticketing/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bus_ticketing/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bus_ticketing/features/auth/domain/repositories/auth_repository.dart';
import 'package:bus_ticketing/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:bus_ticketing/features/bus_search/data/datasources/trip_remote_datasource.dart';
import 'package:bus_ticketing/features/bus_search/data/repositories/trip_repository_impl.dart';
import 'package:bus_ticketing/features/bus_search/domain/repositories/trip_repository.dart';
import 'package:bus_ticketing/features/driver_dashboard/data/datasources/driver_remote_datasource.dart';
import 'package:bus_ticketing/features/driver_dashboard/data/repositories/driver_repository_impl.dart';
import 'package:bus_ticketing/features/driver_dashboard/domain/repositories/driver_repository.dart';
import 'package:bus_ticketing/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final tokenStorage = TokenStorage();
    final dioClient = DioClient();
    final authRepository = AuthRepositoryImpl(
      AuthRemoteDataSource(dioClient.dio),
      tokenStorage,
    );
    final tripRepository = TripRepositoryImpl(
      TripRemoteDataSource(dioClient.dio),
    );
    final driverRepository = DriverRepositoryImpl(
      DriverRemoteDataSource(dioClient.dio),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<TripRepository>.value(value: tripRepository),
          RepositoryProvider<DriverRepository>.value(value: driverRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ThemeBloc(prefs)),
            BlocProvider(create: (_) => ConnectivityCubit()),
            BlocProvider(
              create: (_) => AuthCubit(authRepository, tokenStorage),
            ),
          ],
          child: const MoovitApp(),
        ),
      ),
    );

    // Advance the fake clock past the 3-second splash screen minimum delay,
    // so no pending timers are left when the test tears down the widget tree.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(); // settle follow-up frames

    expect(find.byType(MoovitApp), findsOneWidget);
  });
}
