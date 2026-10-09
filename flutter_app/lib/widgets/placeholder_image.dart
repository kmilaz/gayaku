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
    this.color = AppColors.beige,
  });

  final String imagePath;
  final IconData icon;
  final BoxFit fit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: Icon(icon, size: 42, color: AppColors.tan)),
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
