import 'package:flutter/material.dart';

/// Standard route for pushed screens. Uses MaterialPageRoute so the theme's
/// PageTransitionsTheme applies — including Android's predictive-back preview,
/// which a custom PageRouteBuilder would silently opt out of.
Route<T> appRoute<T>(Widget page) =>
    MaterialPageRoute<T>(builder: (_) => page);
