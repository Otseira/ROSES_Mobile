import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  final bool onDark;
  const ProfileAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 40,
    this.onDark = false,
  });

  String get _initial {
    final n = name.trim();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark
            ? Colors.white.withOpacity(0.2) // header hijau
            : AppColors.primary.withOpacity(0.12), // latar terang
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: onDark ? Colors.white : AppColors.primary,
        ),
      ),
    );

    Widget inner;
    if (url == null || url!.isEmpty) {
      inner = fallback;
    } else {
      final cacheDim = (radius * 4).round();
      inner = Image.network(
        url!,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        cacheWidth: cacheDim,
        cacheHeight: cacheDim,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return ClipOval(
      child: SizedBox(width: radius * 2, height: radius * 2, child: inner),
    );
  }
}
