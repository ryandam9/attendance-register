import 'package:flutter/material.dart';

/// Semantic colour tokens shared across the whole app.
///
/// Using slightly deeper shades than bare Material primaries to ensure
/// readable contrast on white/light surfaces and in calendar dots.
abstract final class AppColors {
  static const Color attendance = Color(0xFF2E7D32); // green[800]
  static const Color holiday    = Color(0xFF1565C0); // blue[800]
  static const Color sickLeave  = Color(0xFFE65100); // deepOrange[900]
}
