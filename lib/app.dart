import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/client/main_navigation.dart';
import 'screens/client/ride/public_ride_tracking_screen.dart';
import 'screens/driver/home/driver_home_screen.dart';

class MotoGoApp extends StatelessWidget {
  const MotoGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const _SessionGate(),
    );
  }
}

/// Decide the first screen without forcing the user to log in again.
///
/// The session is stored with SharedPreferences, which persists across
/// app restarts and browser refreshes. It is cleared only when the user
/// explicitly logs out (or the app clears the session).
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _resolveInitialScreen();
  }

  Future<Widget> _resolveInitialScreen() async {
    // Public ride links must remain accessible without login.
    final rideId = int.tryParse(
      Uri.base.queryParameters['ride_id'] ?? '',
    );

    if (rideId != null && rideId > 0) {
      return PublicRideTrackingScreen(rideId: rideId);
    }

    // Restore the previous authenticated session.
    final logged = await AuthService.isLogged();

    if (!logged) {
      return const LoginScreen();
    }

    final accountType = await AuthService.getAccountType();

    // Reagenda as mensagens motivacionais diariamente.
    // O agendamento é local no Android/iOS e continua funcionando
    // mesmo quando o aplicativo não estiver aberto.
    if (accountType == 'driver' || accountType == 'client') {
      await NotificationService.scheduleDailyMotivation(
        accountType: accountType!,
      );
    }

    switch (accountType) {
      case 'admin':
        return const AdminHomeScreen();
      case 'driver':
        return const DriverHomeScreen();
      case 'client':
      default:
        return const MainNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7F6),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const LoginScreen();
        }

        return snapshot.data!;
      },
    );
  }
}
