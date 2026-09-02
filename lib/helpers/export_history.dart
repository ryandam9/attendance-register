import 'package:flutter/material.dart';

import '../services/export_saver.dart';
import '../services/export_service.dart';

/// Builds and saves the complete Excel history while keeping all user-facing
/// feedback consistent wherever the action is exposed.
Future<void> exportHistoryAsExcel(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ExportService.buildXlsx();
  if (result.rows == 0) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Nothing to export yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final now = DateTime.now();
  final stamp =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  final saved = await ExportSaver.saveXlsx(
    result.bytes,
    suggestedName: 'attendance-register-complete-history-$stamp.xlsx',
  );
  final entries =
      '${result.rows} history ${result.rows == 1 ? 'entry' : 'entries'}';

  switch (saved.outcome) {
    case SaveOutcome.saved:
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved $entries to ${saved.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    case SaveOutcome.shared:
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported $entries.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    case SaveOutcome.cancelled:
      break;
    case SaveOutcome.error:
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save the file.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
