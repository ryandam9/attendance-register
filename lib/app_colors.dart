import 'package:flutter/material.dart';

/// Semantic colour tokens shared across the whole app.
///
/// Using slightly deeper shades than bare Material primaries to ensure
/// readable contrast on white/light surfaces and in calendar dots.
abstract final class AppColors {
  static const Color attendance  = Color(0xFF2E7D32); // green[800]
  static const Color holiday     = Color(0xFF1565C0); // blue[800]
  static const Color sickLeave   = Color(0xFFE65100); // deepOrange[900]
  static const Color annualLeave = Color(0xFF6A1B9A); // purple[800]
  static const Color carersLeave = Color(0xFF00838F); // cyan[800]
  static const Color workFromHome = Color(0xFFAD1457); // pink[800]
  static const Color miscLeave = Color(0xFF616161); // grey[700]
}
