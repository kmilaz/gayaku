import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Display name, falling back to the local part of the e-mail address.
String _greetingName(AuthUser? user) {
  final name = (user?.displayName ?? '').trim();
  if (name.isNotEmpty) return name;
  final email = (user?.email ?? '').trim();
  return email.isEmpty ? '' : email.split('@').first;
}

/// Time-of-day greeting plus the user name and a notification bell.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  static String greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingFor(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 18 / 13,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // The signed-in account, so the greeting matches the profile
                // screen instead of a demo name.
                _greetingName(authService.currentUser),
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 32,
                  height: 38 / 32,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
