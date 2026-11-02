import 'package:flutter/material.dart';

/// Confirms a successful check-in with a brief floating message: "Your
/// attendance has been recorded." The Today card on Home carries the lasting
/// recorded state, so this only needs to acknowledge the moment and fade.
Future<void> showCheckInCelebration(
  BuildContext context, {
  required String officeName,
  required DateTime date,
}) async {
  final cs = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  await messenger
      .showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Semantics(
            liveRegion: true,
            label: 'Attendance recorded at $officeName',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: cs.inversePrimary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Your attendance has been recorded.'),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
      .closed;
}
