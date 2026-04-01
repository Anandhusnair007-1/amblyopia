import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';

// Zest-style bottom nav:
// • Dark background matching app (#1A1A1A)
// • Active item: cyan pill background + icon + label
// • Inactive item: icon only, dim color
// • Smooth animated pill container

class PatientBottomNav extends StatelessWidget {
  const PatientBottomNav({
    super.key,
    required this.currentRoute,
    this.light = false,
  });

  final String currentRoute;
  final bool light;

  static const _kBg = Color(0xFF1A1A1A);
  static const _kBorder = Color(0xFF2A2A2A);
  static const _kLightBg = Color(0xFFFFFFFF);
  static const _kLightBorder = Color(0xFFE3EAF2);

  int _index() {
    switch (currentRoute) {
      case AppRouter.patientTestHistory:
        return 1;
      case AppRouter.myReports:
        return 2;
      case AppRouter.patientProfile:
        return 3;
      default:
        return 0;
    }
  }

  void _go(BuildContext context, int index) {
    final target = switch (index) {
      1 => AppRouter.patientTestHistory,
      2 => AppRouter.myReports,
      3 => AppRouter.patientProfile,
      _ => AppRouter.patientHome,
    };
    if (currentRoute == target) return;
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  Widget build(BuildContext context) {
    final idx = _index();
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: light ? _kLightBg : _kBg,
        border: Border(
            top: BorderSide(
                color: light ? _kLightBorder : _kBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ZestNavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            active: idx == 0,
            light: light,
            onTap: () => _go(context, 0),
          ),
          _ZestNavItem(
            icon: Icons.science_rounded,
            label: 'Tests',
            active: idx == 1,
            light: light,
            onTap: () => _go(context, 1),
          ),
          _ZestNavItem(
            icon: Icons.description_rounded,
            label: 'Reports',
            active: idx == 2,
            light: light,
            onTap: () => _go(context, 2),
          ),
          _ZestNavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            active: idx == 3,
            light: light,
            onTap: () => _go(context, 3),
          ),
        ],
      ),
    );
  }
}

class _ZestNavItem extends StatelessWidget {
  const _ZestNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.light,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool light;
  final VoidCallback onTap;

  static const _kAccent = Color(0xFF00B4D8);
  static const _kInactive = Color(0xFF555566);
  static const _kLightInactive = Color(0xFF6B7A90);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: active
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? (light
                  ? const Color(0xFFE9F7FB)
                  : _kAccent.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: active
              ? Border.all(
                  color: light
                      ? const Color(0xFFB9E8F3)
                      : _kAccent.withValues(alpha: 0.25),
                  width: 1,
                )
              : null,
        ),
        child: active
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _kAccent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kAccent,
                    ),
                  ),
                ],
              )
            : Icon(icon, color: light ? _kLightInactive : _kInactive, size: 22),
      ),
    );
  }
}
