import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../auth/presentation/cubit/auth_cubit.dart';
import '../auth/presentation/cubit/auth_state.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // On the Home tab, let the system handle back (exits the app) since
      // there's nothing before it. On any other tab, back returns to Home
      // first instead of exiting or doing nothing.
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navigationShell.goBranch(0);
      },
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            // Replace the entire stack so the user cannot go back
            context.go(AppRoutes.login);
          }
        },
        child: Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number_rounded),
                label: 'Tickets',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
