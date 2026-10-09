import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Beige placeholder box with a centered icon, layered behind an
/// [AssetImage] so the layout works before photo assets are supplied.
/// Missing assets fall back to the placeholder via [errorBuilder].
class PlaceholderImage extends StatelessWidget {
  const PlaceholderImage({
    super.key,
    required this.imagePath,
    required this.icon,
    this.fit = BoxFit.cover,
  });

  final String imagePath;
  final IconData icon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.beige,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: Icon(icon, size: 40, color: AppColors.tan)),
          Image.asset(
            imagePath,
            fit: fit,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

void showComingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label coming soon')));
}

/// Plain transient message — validation and other real (non-stub) feedback.
void showNote(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
