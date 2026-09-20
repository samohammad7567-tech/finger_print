import 'dart:io';

import 'package:bidi/bidi.dart' as bidi;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Lays a plain table out on an A4 page and writes it next to the other
/// exports.
///
/// Every report in the app is the same shape — a title, the span it covers, a
/// grid of already-formatted strings and a totals line — so the fonts, the
/// Arabic shaping and the output folder live here once rather than in each
/// data source that wants a file.
class ReportPdfEngine {
  /// Windows ships these, and both carry the full Arabic set. The bundled
  /// Helvetica does not, so without one of them Arabic names come out blank.
  static const _systemFonts = [
    r'C:\Windows\Fonts\tahoma.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    r'C:\Windows\Fonts\segoeui.ttf',
  ];
  static const _systemBoldFonts = [
    r'C:\Windows\Fonts\tahomabd.ttf',
    r'C:\Windows\Fonts\arialbd.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
  ];

  static final _arabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFEFF]');

  /// Renders [rows] under [headers] and returns the file it wrote.
  ///
  /// [folder] defaults to a GuardSync Reports folder in the user's documents —
  /// the same place the database backup goes, so an admin has one place to
  /// look. Tests pass a temporary directory instead.
  Future<File> writeTable({
    required String title,
    required String range,
    required String generatedAt,
    required List<String> headers,
    required List<List<String>> rows,
    required bool isArabic,
    required String fileName,
    String totalsLabel = '',
    List<String> totals = const [],
    Map<int, pw.TableColumnWidth> columnWidths = const {},
    Directory? folder,
  }) async {
    final base = await _loadFont(_systemFonts);
    final bold = await _loadFont(_systemBoldFonts) ?? base;

    final document = pw.Document(
      theme: base == null
          ? null
          : pw.ThemeData.withFont(base: base, bold: bold),
    );

    final direction = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    // On an Arabic page the renderer shapes and reorders the text itself. On an
    // English one it does not, and Arabic names — which is what the terminal
    // gives us — would come out as disconnected letters in reverse, so they are
    // shaped here instead.
    String shape(String text) => isArabic || !_arabic.hasMatch(text)
        ? text
        : String.fromCharCodes(bidi.logicalToVisual(text));

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Directionality(
            textDirection: direction,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _header(title, range, generatedAt, shape),
                pw.SizedBox(height: 12),
                _table(headers, rows, columnWidths, shape),
                if (totals.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _totals(totalsLabel, totals, shape),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final target =
        folder ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'GuardSync Reports',
          ),
        );
    await target.create(recursive: true);

    final file = File(p.join(target.path, fileName));
    await file.writeAsBytes(await document.save());
    return file;
  }

  /// Hands the finished file to whatever the machine opens PDFs with. A failure
  /// here is not a failure of the export — the file is already on disk.
  Future<void> open(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // Nothing to do: the admin still has the path.
    }
  }

  pw.Widget _header(
    String title,
    String range,
    String generatedAt,
    String Function(String) shape,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        shape(title),
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        shape(range),
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
      pw.Text(
        shape(generatedAt),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    ],
  );

  pw.Widget _table(
    List<String> headers,
    List<List<String>> rows,
    Map<int, pw.TableColumnWidth> columnWidths,
    String Function(String) shape,
  ) => pw.TableHelper.fromTextArray(
    headers: headers.map(shape).toList(),
    data: rows.map((r) => r.map(shape).toList()).toList(),
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellHeight: 20,
    // Zebra striping: a wide row is easy to lose track of across a page.
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: columnWidths,
  );

  pw.Widget _totals(
    String label,
    List<String> totals,
    String Function(String) shape,
  ) => pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          shape('$label:  '),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Expanded(
          child: pw.Text(
            shape(totals.join('     ')),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );

  Future<pw.Font?> _loadFont(List<String> candidates) async {
    for (final path in candidates) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        return pw.Font.ttf((await file.readAsBytes()).buffer.asByteData());
      } catch (_) {
        // Try the next one; a missing or unreadable font is not fatal.
      }
    }
    return null;
  }
}
