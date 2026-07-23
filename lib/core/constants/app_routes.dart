import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/absensi/screens/absensi_screen.dart';
import '../../features/lembur/screens/lembur_screen.dart';
import '../../features/lembur/screens/oncall_screen.dart';
import '../../features/roster/screens/roster_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String home = '/home';
  static const String absensiMasuk = '/absensi/masuk';
  static const String absensiPulang = '/absensi/pulang';
  static const String lembur = '/lembur';
  static const String oncall = '/lembur/oncall';
  static const String roster = '/roster';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginScreen(),
    home: (_) => const HomeScreen(),
    absensiMasuk: (_) => const AbsensiScreen(type: 'masuk'),
    absensiPulang: (_) => const AbsensiScreen(type: 'pulang'),
    lembur: (_) => const LemburScreen(),
    oncall: (_) => const OnCallScreen(),
    roster: (_) => const RosterScreen(),
    profile: (_) => const ProfileScreen(),
  };
}
