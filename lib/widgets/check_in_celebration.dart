import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows a centered, animated "attendance recorded" celebration — a check badge
/// that pops in, a confetti burst, and an auto-dismiss — instead of a snackbar.
/// Used when a foreground auto check-in records the day.
Future<void> showCheckInCelebration(
  BuildContext context, {
  required String officeName,
  required DateTime date,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Attendance recorded',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) =>
        _CheckInCelebration(officeName: officeName, date: date),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _CheckInCelebration extends StatefulWidget {
  final String officeName;
  final DateTime date;
  const _CheckInCelebration({required this.officeName, required this.date});

  @override
  State<_CheckInCelebration> createState() => _CheckInCelebrationState();
}

class _CheckInCelebrationState extends State<_CheckInCelebration> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1200),
  );
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _confetti.play();
    _autoClose = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('EEEE, d MMM');
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 26,
            maxBlastForce: 26,
            minBlastForce: 8,
            gravity: 0.25,
            shouldLoop: false,
            colors: [
              cs.primary,
              cs.secondary,
              cs.tertiary,
              Colors.green.shade500,
            ],
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Attendance recorded!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You're at ${widget.officeName}",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFmt.format(widget.date),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
