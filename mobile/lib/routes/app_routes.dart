import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/home/caregiver_home_screen.dart';
import '../features/home/patient_home_screen.dart';
import '../features/splash/splash_screen.dart';
import '../models/user_role.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const roleSelection = '/role-selection';
  static const login = '/login';
  static const register = '/register';
  static const patientHome = '/home/patient';
  static const caregiverHome = '/home/caregiver';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fade(const SplashScreen());
      case roleSelection:
        return _slide(const RoleSelectionScreen());
      case login:
        final role = settings.arguments as UserRole;
        return _slide(LoginScreen(role: role));
      case register:
        final role = settings.arguments as UserRole;
        return _slide(RegisterScreen(role: role));
      case patientHome:
        return _fade(const PatientHomeScreen());
      case caregiverHome:
        return _fade(const CaregiverHomeScreen());
      default:
        return _fade(const SplashScreen());
    }
  }

  static PageRouteBuilder<dynamic> _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  static PageRouteBuilder<dynamic> _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
