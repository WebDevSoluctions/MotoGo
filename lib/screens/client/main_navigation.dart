import 'package:flutter/material.dart';

import '../../config/colors.dart';

import 'home/home_screen.dart';
import 'history/ride_history_screen.dart';
import 'favorites/favorites_screen.dart';
import 'profile/profile_screen.dart';

import 'ride/ride_request_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
  });

  @override
  State<MainNavigation> createState() =>
      _MainNavigationState();
}

class _MainNavigationState
    extends State<MainNavigation> {
  // ============================================================
  // ABA ATUAL
  // ============================================================

  int currentIndex = 0;

  // ============================================================
  // PÁGINAS
  // ============================================================

  Widget _currentPage() {
    switch (currentIndex) {
      case 1:
        return const RideHistoryScreen();
      case 2:
        return const FavoritesScreen();
      case 3:
        return const ProfileScreen();
      case 0:
      default:
        return const HomeScreen();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ========================================================
      // CONTEÚDO
      // ========================================================

      body: AnimatedSwitcher(
        duration:
            const Duration(milliseconds: 250),

        child: KeyedSubtree(
          key: ValueKey(currentIndex),
          child: _currentPage(),
        ),
      ),

      // ========================================================
      // NAVEGAÇÃO INFERIOR
      // ========================================================

      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            currentIndex,

        height: 78,

        backgroundColor:
            Colors.white,

        indicatorColor:
            AppColors.primary
                .withOpacity(0.15),

        elevation: 8,

        labelBehavior:
            NavigationDestinationLabelBehavior
                .alwaysShow,

        onDestinationSelected:
            (index) {
          setState(() {
            currentIndex = index;
          });
        },

        destinations: const [
          // ====================================================
          // HOME
          // ====================================================

          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),

            selectedIcon: Icon(
              Icons.home,
            ),

            label: 'Home',
          ),

          // ====================================================
          // HISTÓRICO
          // ====================================================

          NavigationDestination(
            icon: Icon(
              Icons.history,
            ),

            selectedIcon: Icon(
              Icons.history,
            ),

            label: 'Histórico',
          ),

          // ====================================================
          // FAVORITOS
          // ====================================================

          NavigationDestination(
            icon: Icon(
              Icons.favorite_outline,
            ),

            selectedIcon: Icon(
              Icons.favorite,
            ),

            label: 'Favoritos',
          ),

          // ====================================================
          // PERFIL
          // ====================================================

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),

            selectedIcon: Icon(
              Icons.person,
            ),

            label: 'Perfil',
          ),
        ],
      ),

      // ========================================================
      // BOTÃO DE SOLICITAR CORRIDA
      // ========================================================

      floatingActionButton:
          FloatingActionButton(
        backgroundColor:
            AppColors.primary,

        foregroundColor:
            Colors.white,

        elevation: 6,

        onPressed: () {
          Navigator.push(
            context,

            MaterialPageRoute(
              builder: (_) =>
                  const RideRequestScreen(),
            ),
          );
        },

        child: const Icon(
          Icons.two_wheeler_rounded,
        ),
      ),
    );
  }
}