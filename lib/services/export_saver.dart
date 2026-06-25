import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What happened when the user asked to save an export.
enum SaveOutcome { saved, shared, cancelled, error }

class SaveExportResult {
  final SaveOutcome outcome;

  /// The path written to, when [outcome] is [SaveOutcome.saved].
  final String? path;
  const SaveExportResult(this.outcome, {this.path});
}

/// Saves exported file [bytes] to disk: a native "Save As" dialog on desktop,
/// or the system share sheet on mobile (so it can go to Files, Drive, email…).
class ExportSaver {
  ExportSaver._();

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<SaveExportResult> saveXlsx(
    List<int> bytes, {
    required String suggestedName,
  }) {
    return _save(
      bytes,
      suggestedName: suggestedName,
      extension: 'xlsx',
      mimeType: _xlsxMime,
      typeLabel: 'Excel workbook',
    );
  }

  static Future<SaveExportResult> _save(
    List<int> bytes, {
    required String suggestedName,
    required String extension,
    required String mimeType,
    required String typeLabel,
  }) async {
    try {
      final isDesktop =
          Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      if (isDesktop) {
        final location = await getSaveLocation(
          suggestedName: suggestedName,
          acceptedTypeGroups: [
            XTypeGroup(label: typeLabel, extensions: [extension]),
          ],
        );
        if (location == null) {
          return const SaveExportResult(SaveOutcome.cancelled);
        }
        await File(location.path).writeAsBytes(bytes, flush: true);
        return SaveExportResult(SaveOutcome.saved, path: location.path);
      }

      // Mobile: write to a temp file and hand it to the share sheet.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$suggestedName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([
        XFile(file.path, mimeType: mimeType, name: suggestedName),
      ], subject: 'Attendance history');
      return SaveExportResult(SaveOutcome.shared, path: file.path);
    } catch (_) {
      return const SaveExportResult(SaveOutcome.error);
    }
  }
}
