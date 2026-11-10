import 'package:flutter/material.dart';

/// One-line message at the bottom of the screen; used for backend failures and
/// for the "nothing to combine yet" hints.
void showNote(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
