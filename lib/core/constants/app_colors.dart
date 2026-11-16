import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary (Emerald Palette - Identik dengan SIRO Mobile Web Tailwind)
  static const Color primary = Color(0xFF10B981); // emerald-500
  static const Color primaryLight = Color(0xFF34D399); // emerald-400
  static const Color primaryDark = Color(0xFF059669); // emerald-600

  // Secondary (Rose / Pulang & Danger)
  static const Color secondary = Color(0xFFF43F5E); // rose-500
  static const Color secondaryLight = Color(0xFFFB7185); // rose-400
  static const Color secondaryDark = Color(0xFFE11D48); // rose-600

  // Background & Surface
  static const Color background = Color(0xFFF8FAFC); // slate-50
  static const Color surface = Colors.white;
  static const Color cardBg = Colors.white;

  // Text (Slate Palette - Identik dengan Tailwind Slate)
  static const Color textPrimary = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textHint = Color(0xFF94A3B8); // slate-400

  // Status
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color info = Color(0xFF3B82F6); // blue-500

  // Soft tints (untuk chip, badge, dan kartu modern dengan kontras tinggi)
  static const Color primarySoft = Color(0xFFECFDF5); // emerald-50
  static const Color secondarySoft = Color(0xFFFFF1F2); // rose-50
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color infoSoft = Color(0xFFEFF6FF);
  static const Color warningSoft = Color(0xFFFFFBEB); // amber-50

  // Neutral Borders
  static const Color border = Color(0xFFF1F5F9); // slate-100
  static const Color borderLight = Color(0xFFE2E8F0); // slate-200
  static const Color divider = Color(0xFFF1F5F9); // slate-100
}
