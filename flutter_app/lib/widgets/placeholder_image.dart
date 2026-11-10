import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Beige placeholder box with a centered icon, layered behind the garment
/// photo so the layout works before photo assets are supplied.
///
/// [imagePath] is either a bundled asset (`assets/images/…`) or the absolute
/// path of a scanned cutout in the app documents directory. Missing files fall
/// back to the placeholder via `errorBuilder`.
class PlaceholderImage extends StatelessWidget {
  const PlaceholderImage({
    super.key,
    required this.imagePath,
    required this.icon,
    this.fit = BoxFit.cover,
    this.color,
  });

  final String imagePath;

  final IconData icon;
  final BoxFit fit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      color: color ?? palette.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: Icon(icon, size: 28, color: palette.accentInk)),
          if (File(imagePath).isAbsolute)
            Image.file(
              File(imagePath),
              fit: fit,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else
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
