// Generates erd.pdf in the project root: the Arabic data-model and
// architecture document for GuardSync.
//
// Run with:  dart run tool/generate_erd_pdf.dart
//
// Pure Dart on purpose — no Flutter binding, no path_provider — so it can be
// regenerated from a terminal whenever the schema in
// lib/core/database/app_database.dart moves.

import 'dart:io';

import 'package:bidi/bidi.dart' as bidi;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------------- palette --

const navy = PdfColor.fromInt(0xFF0E2A47);
const navySoft = PdfColor.fromInt(0xFF1B3D63);
const teal = PdfColor.fromInt(0xFF177E89);
const plum = PdfColor.fromInt(0xFF6C4C93);
const gold = PdfColor.fromInt(0xFFB88A1E);
const ink = PdfColor.fromInt(0xFF1A2027);
const muted = PdfColor.fromInt(0xFF5C6773);
const rule = PdfColor.fromInt(0xFFD7DEE6);
const wash = PdfColor.fromInt(0xFFF5F8FB);
const wash2 = PdfColor.fromInt(0xFFE7EEF6);
const white = PdfColors.white;

late pw.Font fBase;
late pw.Font fBold;

const rtl = pw.TextDirection.rtl;
const ltr = pw.TextDirection.ltr;

// ------------------------------------------------------------- text tools --

final _hasArabic = RegExp('[؀-ۿݐ-ݿ]');

/// Arabic short vowels and the superscript alef.
final _harakat = RegExp('[ً-ْٰ]');
final _safeCache = <String, String>{};

/// RIGHT-TO-LEFT MARK. The bidi algorithm picks a paragraph's direction from
/// its first strong character, so a sentence opening with a Latin word — a
/// package name, a table name — is laid out as an LTR paragraph and comes out
/// with its lines in reverse order. This zero-width mark settles the direction
/// before the first real character is read.
const _rlm = '‏';

/// The bidi algorithm the pdf package runs at layout time throws a RangeError
/// on a few diacritic sequences — a hamza-carrying alef followed immediately
/// by a damma is one of them. The text is checked here, where the failure can
/// still be traced to a sentence, and only the sentences that would crash lose
/// their vowel marks.
String bidiSafe(String s) => _safeCache.putIfAbsent(s, () {
  bool renders(String candidate) {
    try {
      bidi.BidiString.fromLogical(candidate).paragraphs;
      return true;
    } catch (_) {
      return false;
    }
  }

  final marked = '$_rlm$s';
  if (renders(marked)) return marked;
  final stripped = '$_rlm${s.replaceAll(_harakat, '')}';
  if (!renders(stripped)) {
    stderr.writeln('warning: bidi cannot lay out: $s');
  }
  return stripped;
});

pw.Widget ar(
  String s, {
  double size = 10,
  bool bold = false,
  PdfColor color = ink,
  double spacing = 3.2,
  pw.TextAlign align = pw.TextAlign.right,
}) => pw.Text(
  bidiSafe(s),
  textAlign: align,
  style: pw.TextStyle(
    font: bold ? fBold : fBase,
    fontSize: size,
    color: color,
    lineSpacing: spacing,
  ),
);

/// Latin identifiers — table names, columns, types — never shaped, always
/// left-to-right whatever the surrounding paragraph does.
pw.Widget en(
  String s, {
  double size = 9,
  bool bold = false,
  PdfColor color = ink,
  pw.TextAlign align = pw.TextAlign.left,
}) => pw.Directionality(
  textDirection: ltr,
  child: pw.Text(
    s,
    textAlign: align,
    style: pw.TextStyle(
      font: bold ? fBold : fBase,
      fontSize: size,
      color: color,
    ),
  ),
);

pw.Widget gap(double h) => pw.SizedBox(height: h);

pw.Widget chapter(String number, String title, [String subtitle = '']) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 6, bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 30,
                height: 30,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: navy,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: en(number, size: 13, bold: true, color: white),
              ),
              pw.SizedBox(width: 9),
              pw.Expanded(
                child: ar(title, size: 15.5, bold: true, color: navy),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            gap(4),
            ar(subtitle, size: 8.6, color: muted),
          ],
          gap(6),
          pw.Container(height: 2, color: gold, width: 54),
        ],
      ),
    );

pw.Widget heading(String title) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(width: 4, height: 13, color: teal),
      pw.SizedBox(width: 7),
      pw.Expanded(child: ar(title, size: 11.6, bold: true, color: navySoft)),
    ],
  ),
);

pw.Widget para(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 7),
  child: ar(text, size: 9.8, align: pw.TextAlign.justify),
);

pw.Widget bullet(String text, {PdfColor dot = teal}) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 5, right: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 4),
        width: 4.5,
        height: 4.5,
        decoration: pw.BoxDecoration(color: dot, shape: pw.BoxShape.circle),
      ),
      pw.SizedBox(width: 7),
      pw.Expanded(child: ar(text, size: 9.6, align: pw.TextAlign.justify)),
    ],
  ),
);

pw.Widget bullets(List<String> items, {PdfColor dot = teal}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: items.map((e) => bullet(e, dot: dot)).toList(),
);

/// A coloured aside — the rule behind a design decision, or a warning.
pw.Widget callout(String title, String body, {PdfColor color = teal}) =>
    pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 6, bottom: 9),
      padding: const pw.EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: pw.BoxDecoration(
        color: wash,
        border: pw.Border(right: pw.BorderSide(color: color, width: 3)),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          bottomLeft: pw.Radius.circular(4),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ar(title, size: 9.6, bold: true, color: color),
          gap(3),
          ar(body, size: 9.2, align: pw.TextAlign.justify),
        ],
      ),
    );

/// A right-to-left table. The pdf package lays tables out left-to-right
/// regardless of the page direction, so the columns are reversed here and the
/// cells pinned to the right instead.
pw.Widget table({
  required List<String> headers,
  required List<List<String>> rows,
  List<double> flex = const [],
  List<bool> latin = const [],
  double fontSize = 8.4,
  PdfColor headerColor = navy,
}) {
  final n = headers.length;
  final weights = flex.isEmpty ? List<double>.filled(n, 1) : flex;
  final isLatin = latin.isEmpty ? List<bool>.filled(n, false) : latin;

  final widths = <int, pw.TableColumnWidth>{};
  for (var i = 0; i < n; i++) {
    widths[i] = pw.FlexColumnWidth(weights[n - 1 - i]);
  }

  // The header is always Arabic prose, even above a column of table names,
  // and so is any cell that turns out to carry Arabic after all — laying
  // Arabic out left-to-right leaves it unshaped and unreadable.
  pw.Widget cell(String text, int logical, {required bool header}) {
    final child = isLatin[logical] && !header && !_hasArabic.hasMatch(text)
        ? en(
            text,
            size: fontSize,
            bold: header,
            color: header ? white : ink,
            align: pw.TextAlign.right,
          )
        : ar(
            text,
            size: fontSize,
            bold: header,
            color: header ? white : ink,
            spacing: 2,
          );
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: pw.SizedBox(width: double.infinity, child: child),
    );
  }

  return pw.Table(
    border: pw.TableBorder.symmetric(
      inside: const pw.BorderSide(color: rule, width: 0.5),
      outside: const pw.BorderSide(color: rule, width: 0.5),
    ),
    columnWidths: widths,
    children: [
      pw.TableRow(
        // Carried onto the next page when a long table breaks.
        repeat: true,
        decoration: pw.BoxDecoration(color: headerColor),
        children: [
          for (var i = n - 1; i >= 0; i--) cell(headers[i], i, header: true),
        ],
      ),
      for (var r = 0; r < rows.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: r.isOdd ? wash : white),
          children: [
            for (var i = n - 1; i >= 0; i--) cell(rows[r][i], i, header: false),
          ],
        ),
    ],
  );
}

// ------------------------------------------------------------ ERD drawing --

/// One column line inside an entity box: key marker, name, type.
class Col {
  const Col(this.name, this.type, [this.key = '']);
  final String name;
  final String type;

  /// 'PK', 'FK', 'UQ', 'IX' or empty.
  final String key;
}

PdfColor _keyColor(String key) => switch (key) {
  'PK' => gold,
  'FK' => teal,
  'UQ' => plum,
  'IX' => navySoft,
  _ => rule,
};

pw.Widget entityBox({
  required String name,
  required String label,
  required List<Col> columns,
  PdfColor color = navy,
  String footnote = '',
}) => pw.Container(
  decoration: pw.BoxDecoration(
    color: white,
    border: pw.Border.all(color: color, width: 1),
    borderRadius: pw.BorderRadius.circular(5),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(4),
            topRight: pw.Radius.circular(4),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            en(name, size: 8.6, bold: true, color: white),
            pw.SizedBox(height: 1),
            ar(label, size: 6.8, color: PdfColors.white, spacing: 0),
          ],
        ),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            for (final c in columns)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 1.6),
                child: pw.Directionality(
                  textDirection: ltr,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 15,
                        height: 7.5,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: c.key.isEmpty ? white : _keyColor(c.key),
                          border: pw.Border.all(
                            color: c.key.isEmpty ? rule : _keyColor(c.key),
                            width: 0.5,
                          ),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: c.key.isEmpty
                            ? pw.SizedBox()
                            : pw.Text(
                                c.key,
                                style: pw.TextStyle(
                                  font: fBold,
                                  fontSize: 4.8,
                                  color: white,
                                ),
                              ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                        child: pw.Text(
                          c.name,
                          maxLines: 1,
                          style: pw.TextStyle(
                            font: c.key == 'PK' ? fBold : fBase,
                            fontSize: 6.9,
                            color: ink,
                          ),
                        ),
                      ),
                      pw.Text(
                        c.type,
                        style: pw.TextStyle(
                          font: fBase,
                          fontSize: 6.2,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (footnote.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Container(height: 0.5, color: rule),
              pw.SizedBox(height: 3),
              ar(footnote, size: 6.2, color: muted, spacing: 0.8),
            ],
          ],
        ),
      ),
    ],
  ),
);

/// Canvas y grows upward; the layout above measures from the top.
void _seg(PdfGraphics c, double h, double x1, double y1, double x2, double y2) {
  c.moveTo(x1, h - y1);
  c.lineTo(x2, h - y2);
}

/// An orthogonal connector through [waypoints] given as (x, y) top-left pairs.
void _path(PdfGraphics c, double h, List<List<double>> points) {
  for (var i = 0; i < points.length - 1; i++) {
    _seg(c, h, points[i][0], points[i][1], points[i + 1][0], points[i + 1][1]);
  }
}

/// Crow's foot at the "many" end. [dx] points away from the entity edge.
void _many(PdfGraphics c, double h, double x, double y, double dx) {
  _seg(c, h, x, y, x + dx, y - 5);
  _seg(c, h, x, y, x + dx, y + 5);
  _seg(c, h, x, y, x + dx, y);
}

/// The single tick that marks the "one" end.
void _one(PdfGraphics c, double h, double x, double y, double dx) {
  _seg(c, h, x + dx * 1.4, y - 4.5, x + dx * 1.4, y + 4.5);
}

pw.Widget tag(String text, {PdfColor color = navySoft, bool latin = true}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: white,
        border: pw.Border.all(color: color, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2.5),
      ),
      child: latin
          ? en(text, size: 6.3, bold: true, color: color)
          : ar(text, size: 6.3, bold: true, color: color, spacing: 0),
    );

pw.Widget legendChip(String label, PdfColor color, {bool dashed = false}) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 16,
          height: dashed ? 0 : 1.4,
          decoration: dashed
              ? pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(
                      color: color,
                      width: 1.4,
                      style: pw.BorderStyle.dashed,
                    ),
                  ),
                )
              : pw.BoxDecoration(color: color),
        ),
        pw.SizedBox(width: 5),
        ar(label, size: 7.4, color: ink, spacing: 0),
        pw.SizedBox(width: 14),
      ],
    );

pw.Widget keyChip(String key, String label) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.center,
  children: [
    pw.Container(
      width: 15,
      height: 8,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _keyColor(key),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Text(
        key,
        style: pw.TextStyle(font: fBold, fontSize: 4.8, color: white),
      ),
    ),
    pw.SizedBox(width: 5),
    ar(label, size: 7.4, color: ink, spacing: 0),
    pw.SizedBox(width: 14),
  ],
);

pw.Widget diagramTitle(String title, String subtitle) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Row(
      children: [
        pw.Container(width: 4, height: 16, color: gold),
        pw.SizedBox(width: 8),
        ar(title, size: 14, bold: true, color: navy),
      ],
    ),
    pw.SizedBox(height: 3),
    ar(subtitle, size: 8, color: muted, spacing: 0),
  ],
);

// ------------------------------------------------------------------- main --

Future<pw.Font> _font(List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (await file.exists()) {
      return pw.Font.ttf((await file.readAsBytes()).buffer.asByteData());
    }
  }
  throw StateError('No Arabic-capable font found in: $candidates');
}

String _today() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}/${two(n.month)}/${two(n.day)}';
}

Future<void> main(List<String> args) async {
  fBase = await _font([
    r'C:\Windows\Fonts\tahoma.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    r'C:\Windows\Fonts\segoeui.ttf',
  ]);
  fBold = await _font([
    r'C:\Windows\Fonts\tahomabd.ttf',
    r'C:\Windows\Fonts\arialbd.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
  ]);

  final doc = pw.Document(
    title: 'GuardSync — وثيقة المخطط العلائقي',
    author: 'GuardSync',
    subject: 'Entity Relationship Diagram & Data Dictionary',
  );

  doc.addPage(_cover());
  doc.addPage(_contents());
  doc.addPage(_partOne());
  doc.addPage(_erdCore());
  doc.addPage(_erdDevice());
  doc.addPage(_partTwo());

  // A viewer left open on the file keeps a lock on Windows, so the path can be
  // overridden to write elsewhere.
  final out = File(args.isEmpty ? 'erd.pdf' : args.first);
  await out.writeAsBytes(await doc.save());
  stdout.writeln('wrote ${out.absolute.path}');
}

// ------------------------------------------------------------------ cover --

pw.Page _cover() => pw.Page(
  pageFormat: PdfPageFormat.a4,
  margin: pw.EdgeInsets.zero,
  textDirection: rtl,
  theme: pw.ThemeData.withFont(base: fBase, bold: fBold),
  build: (context) => pw.Stack(
    children: [
      pw.Positioned.fill(child: pw.Container(color: navy)),
      // A quiet geometric wash so the page is not a flat rectangle.
      pw.Positioned(
        left: -90,
        top: -90,
        child: pw.Container(
          width: 300,
          height: 300,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: navySoft,
          ),
        ),
      ),
      pw.Positioned(
        left: 440,
        top: 140,
        child: pw.Container(
          width: 200,
          height: 200,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: navySoft,
          ),
        ),
      ),
      pw.Positioned(
        right: 0,
        top: 0,
        child: pw.Container(width: 9, height: 842, color: gold),
      ),
      pw.Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(66, 92, 74, 54),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 46,
                    height: 46,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: gold,
                      borderRadius: pw.BorderRadius.circular(9),
                    ),
                    child: en('GS', size: 19, bold: true, color: navy),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      en('GuardSync', size: 17, bold: true, color: white),
                      pw.SizedBox(height: 2),
                      ar(
                        'نظام إدارة الحضور والانصراف',
                        size: 9,
                        color: PdfColors.blueGrey200,
                        spacing: 0,
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Container(width: 70, height: 3, color: gold),
              gap(18),
              ar(
                'وثيقة نموذج البيانات',
                size: 34,
                bold: true,
                color: white,
                spacing: 6,
              ),
              gap(4),
              ar(
                'المخطط العلائقي ERD وقاموس البيانات الكامل',
                size: 17,
                color: PdfColors.blueGrey200,
                spacing: 4,
              ),
              gap(16),
              pw.Container(
                width: 380,
                child: ar(
                  'شرح تفصيلي لبنية قاعدة البيانات المحلية، والعلاقات بين '
                  'الجداول، والفهارس والقيود، ومسار البيانات من جهاز البصمة '
                  'حتى سجل الحضور اليومي، إضافةً إلى المعمارية البرمجية '
                  'للتطبيق.',
                  size: 10.5,
                  color: PdfColors.blueGrey100,
                  align: pw.TextAlign.justify,
                  spacing: 5,
                ),
              ),
              pw.Spacer(),
              pw.Container(height: 0.8, color: navySoft),
              gap(14),
              _coverMeta(),
            ],
          ),
        ),
      ),
    ],
  ),
);

pw.Widget _coverMetaItem(String label, String value, {bool latin = false}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ar(label, size: 7.6, color: PdfColors.blueGrey300, spacing: 0),
        pw.SizedBox(height: 3),
        latin
            ? en(value, size: 9.6, bold: true, color: white)
            : ar(value, size: 9.6, bold: true, color: white, spacing: 0),
      ],
    );

pw.Widget _coverMeta() => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _coverMetaItem('المشروع', 'attendence', latin: true),
        ),
        pw.Expanded(
          child: _coverMetaItem('محرك التخزين', 'SQLite', latin: true),
        ),
        pw.Expanded(child: _coverMetaItem('إصدار المخطط', 'v10', latin: true)),
        pw.Expanded(child: _coverMetaItem('عدد الجداول', '12', latin: true)),
      ],
    ),
    gap(14),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _coverMetaItem('المنصة', 'Flutter Windows', latin: true),
        ),
        pw.Expanded(
          child: _coverMetaItem('الجهاز المرتبط', 'ZKTeco 4370', latin: true),
        ),
        pw.Expanded(
          child: _coverMetaItem('تاريخ الإصدار', _today(), latin: true),
        ),
        pw.Expanded(child: _coverMetaItem('التصنيف', 'داخلي')),
      ],
    ),
  ],
);

// --------------------------------------------------------- page furniture --

pw.PageTheme _theme({bool landscape = false}) => pw.PageTheme(
  pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
  textDirection: rtl,
  theme: pw.ThemeData.withFont(base: fBase, bold: fBold),
  margin: landscape
      ? const pw.EdgeInsets.fromLTRB(22, 26, 22, 22)
      : const pw.EdgeInsets.fromLTRB(46, 44, 46, 40),
);

pw.Widget _runningHeader(String section) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 14),
  padding: const pw.EdgeInsets.only(bottom: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: rule, width: 0.6)),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(width: 3, height: 9, color: gold),
      pw.SizedBox(width: 5),
      en('GuardSync', size: 7.6, bold: true, color: navy),
      pw.SizedBox(width: 5),
      ar('وثيقة نموذج البيانات', size: 7.4, color: muted, spacing: 0),
      pw.Spacer(),
      ar(section, size: 7.4, color: muted, spacing: 0),
    ],
  ),
);

pw.Widget _runningFooter(pw.Context context) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 10),
  padding: const pw.EdgeInsets.only(top: 5),
  decoration: const pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: rule, width: 0.6)),
  ),
  child: pw.Row(
    children: [
      ar('نظام GuardSync لإدارة الحضور', size: 7, color: muted, spacing: 0),
      pw.Spacer(),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: wash2,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: en('${context.pageNumber}', size: 7.4, bold: true, color: navy),
      ),
    ],
  ),
);

// --------------------------------------------------------------- contents --

pw.Widget _tocRow(String no, String title, String note) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 11),
  padding: const pw.EdgeInsets.only(bottom: 9),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: rule, width: 0.5)),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 24,
        height: 24,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: wash2,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: en(no, size: 10, bold: true, color: navy),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ar(title, size: 10.6, bold: true, color: ink, spacing: 0),
            gap(3),
            ar(note, size: 8.2, color: muted, spacing: 1.5),
          ],
        ),
      ),
    ],
  ),
);

pw.Page _contents() => pw.Page(
  pageTheme: _theme(),
  build: (context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _runningHeader('الفهرس'),
      ar('فهرس المحتويات', size: 20, bold: true, color: navy),
      gap(5),
      pw.Container(width: 54, height: 2.5, color: gold),
      gap(18),
      _tocRow(
        '01',
        'نظرة عامة على النظام',
        'الغرض من التطبيق، بيئة التشغيل، الحزمة التقنية، ومصادر البيانات.',
      ),
      _tocRow(
        '02',
        'المعمارية البرمجية وطبقات التطبيق',
        'التنظيم النظيف للمجلدات ومسؤولية كل طبقة من الواجهة حتى قاعدة البيانات.',
      ),
      _tocRow(
        '03',
        'المخطط العلائقي — النواة',
        'الموظفون والحضور والأذونات والورديات والأقسام والحسابات.',
      ),
      _tocRow(
        '04',
        'المخطط العلائقي — تكامل جهاز البصمة',
        'البصمات الخام، المطابقات المعلّقة، الإشعارات، العطلات، والعدّادات.',
      ),
      _tocRow(
        '05',
        'قاموس البيانات',
        'جدول تفصيلي لكل عمود: النوع، القيود، والغرض منه.',
      ),
      _tocRow(
        '06',
        'العلاقات والقيود المرجعية',
        'المفاتيح الأجنبية الصريحة والروابط المنطقية وسلوك الحذف المتسلسل.',
      ),
      _tocRow(
        '07',
        'الفهارس وقيود التفرّد',
        'كل فهرس في المخطط والسبب الذي أُنشئ من أجله.',
      ),
      _tocRow(
        '08',
        'تطوّر المخطط عبر الإصدارات',
        'مسار الترقية من الإصدار الأول حتى الإصدار العاشر دون فقدان بيانات.',
      ),
      _tocRow(
        '09',
        'دورة حياة البيانات',
        'من ضغطة الإصبع على الجهاز حتى سجل حضور يومي مُقيَّم.',
      ),
      _tocRow(
        '10',
        'الوحدات الوظيفية',
        'شاشات التطبيق ومصادر البيانات المسؤولة عنها.',
      ),
      _tocRow(
        '11',
        'النسخ الاحتياطي والأمان والقيود',
        'موقع الملف، آلية النسخ، تجزئة كلمات المرور، والمخاطر المعروفة.',
      ),
      _tocRow(
        '12',
        'ملحق: القيم المعتمدة',
        'قيم أعمدة الحالة والمصدر وأنواع الأذونات وأوضاع البصمة الستة.',
      ),
    ],
  ),
);

pw.Widget _code(String text) => pw.Container(
  width: double.infinity,
  margin: const pw.EdgeInsets.only(top: 4, bottom: 9),
  padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
  decoration: pw.BoxDecoration(
    color: wash,
    border: pw.Border.all(color: rule, width: 0.5),
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.Directionality(
    textDirection: ltr,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: fBase,
        fontSize: 7.8,
        color: ink,
        lineSpacing: 2.4,
      ),
    ),
  ),
);

pw.Widget _statCard(String value, String label, PdfColor color) => pw.Expanded(
  child: pw.Container(
    margin: const pw.EdgeInsets.symmetric(horizontal: 3),
    padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 6),
    decoration: pw.BoxDecoration(
      color: wash,
      border: pw.Border(top: pw.BorderSide(color: color, width: 2.2)),
      borderRadius: const pw.BorderRadius.only(
        bottomLeft: pw.Radius.circular(4),
        bottomRight: pw.Radius.circular(4),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        en(
          value,
          size: 16,
          bold: true,
          color: color,
          align: pw.TextAlign.center,
        ),
        gap(3),
        ar(
          label,
          size: 7.4,
          color: muted,
          spacing: 0,
          align: pw.TextAlign.center,
        ),
      ],
    ),
  ),
);

// ----------------------------------------------------- chapters 01 and 02 --

pw.MultiPage _partOne() => pw.MultiPage(
  pageTheme: _theme(),
  header: (context) => _runningHeader('نظرة عامة والمعمارية'),
  footer: _runningFooter,
  build: (context) => [
    chapter(
      '01',
      'نظرة عامة على النظام',
      'ما الذي يفعله التطبيق، وأين تعيش بياناته، ومن أين تأتي.',
    ),
    para(
      'GuardSync تطبيق سطح مكتب مبني بإطار Flutter ويعمل على نظام Windows، '
      'مهمته إدارة حضور وانصراف الموظفين في منشأة واحدة. يقرأ التطبيق '
      'البصمات مباشرةً من جهاز ZKTeco المتصل بالشبكة المحلية عبر المنفذ 4370، '
      'ثم يحوّلها إلى سجلات حضور يومية مُقيَّمة، ويخزّن كل شيء في ملف قاعدة '
      'بيانات SQLite واحد على الجهاز نفسه.',
    ),
    para(
      'لا يوجد خادم ولا قاعدة بيانات مركزية ولا اتصال بالإنترنت. هذا القرار '
      'المعماري هو ما يفسّر معظم تفاصيل المخطط الموصوف في هذه الوثيقة: '
      'كل قيد وكل فهرس وكل جدول مساعد موجود ليؤدي عمله داخل ملف واحد، دون '
      'الاعتماد على خدمة خارجية تضبط التزامن أو تمنع التكرار.',
    ),
    gap(4),
    pw.Row(
      children: [
        _statCard('12', 'جدولاً في قاعدة البيانات', navy),
        _statCard('10', 'إصدارات للمخطط', teal),
        _statCard('2', 'مفتاح أجنبي صريح', gold),
        _statCard('14', 'وحدة وظيفية', plum),
      ],
    ),
    gap(14),
    heading('بيئة التشغيل والحزمة التقنية'),
    table(
      headers: const ['البند', 'القيمة', 'الملاحظة'],
      rows: const [
        ['إطار العمل', 'Flutter · Dart 3.12+', 'بناء موجّه لسطح مكتب Windows'],
        [
          'إدارة الحالة',
          'flutter_bloc · Cubit',
          'كل شاشة يقودها Cubit خاص بها',
        ],
        ['حقن التبعيات', 'get_it', 'كل التسجيلات في service_locator'],
        ['التنقّل', 'go_router', 'المسارات معرَّفة في app_router'],
        [
          'قاعدة البيانات',
          'sqflite_common_ffi',
          'لا توجد نسخة سطح مكتب من sqflite',
        ],
        ['ملف البيانات', 'guardsync.db', 'داخل مجلد بيانات التطبيق'],
        ['الجهاز', 'flutter_zkteco', 'اتصال TCP على المنفذ 4370'],
        ['التعريب', 'easy_localization', 'العربية هي اللغة الأساسية'],
        ['التقارير', 'pdf · excel', 'تصدير ملفات PDF و xlsx'],
        ['التشفير', 'crypto', 'تجزئة كلمات المرور بملح عشوائي'],
      ],
      flex: const [1.1, 1.3, 2.0],
      latin: const [false, true, false],
    ),
    heading('مصادر البيانات الثلاثة'),
    bullets(const [
      'جهاز البصمة: المصدر الأساسي. يُقرأ سجل البصمات كاملاً في كل مزامنة، '
          'ويُخزَّن خامًا في جدول device_punches قبل تحويله إلى سجلات يومية.',
      'الإدخال اليدوي: شاشات الحضور والأذونات، وتُوسم سجلاتها بالمصدر manual '
          'كي لا تدهسها المزامنة التالية.',
      'الاستيراد من Excel: ملف موظفين جاهز يُحمَّل دفعة واحدة عبر '
          'employee_import_excel_data_source.',
    ]),
    callout(
      'لماذا تُخزَّن البصمة الخام ثم تُحوَّل؟',
      'الجهاز يعيد كامل ذاكرته في كل قراءة، لا الجديد فقط. تخزين البصمة الخام '
          'تحت فهرس فريد على الثنائي device_user_id و punch_time يجعل إعادة '
          'المزامنة عملية آمنة لا تُنتج تكرارًا، ويسمح بإعادة بناء سجلات موظف '
          'رُبط بالجهاز متأخرًا دون العودة إلى الجهاز مرة أخرى.',
      color: teal,
    ),
    pw.NewPage(),
    chapter(
      '02',
      'المعمارية البرمجية وطبقات التطبيق',
      'أين يُكتب المنطق، وما الذي لا يُسمح لكل طبقة بفعله.',
    ),
    para(
      'يتبع المشروع معمارية نظيفة مبسّطة: واجهة لا تحمل منطقًا، و Cubit يملك '
      'السلوك، ومصدر بيانات يملك كل ما يمسّ التخزين. لا توجد طبقة domain ولا '
      'use cases — المستودع طبقة تمرير رفيعة فقط، والسبب أن كل عملية هنا '
      'تخاطب مصدرًا واحدًا محليًا، فإضافة طبقة وسيطة كانت ستضيف ملفات لا منطقًا.',
    ),
    _code(
      'lib/\n'
      '  main.dart                      initialization only\n'
      '  core/\n'
      '    database/app_database.dart   schema owner + backup\n'
      '    di/service_locator.dart      get_it registrations\n'
      '    routing/app_router.dart      go_router configuration\n'
      '    localization/lang_keys.dart  translation key constants\n'
      '    pdf/report_pdf_engine.dart   shared A4 report renderer\n'
      '  features/<feature>/\n'
      '    data/\n'
      '      data_source/               all SQL and device I/O\n'
      '      models/                    fromJson / toJson\n'
      '      repos/                     thin delegation\n'
      '    presentation/\n'
      '      cubit/                     state, filters, error keys\n'
      '      refactor/                  body sections, view data\n'
      '      screens/                   creates cubit, renders body\n'
      '      widgets/                   small dumb components',
    ),
    heading('مسؤولية كل طبقة'),
    table(
      headers: const ['الطبقة', 'تملك', 'لا يُسمح لها بـ'],
      rows: const [
        [
          'الشاشة',
          'إنشاء الـ Cubit وعرض جسم الصفحة',
          'أي منطق تخطيط أو دوال بناء داخلية',
        ],
        [
          'الودجت',
          'عرض الحالة وتمرير الأحداث',
          'الوصول إلى قاعدة البيانات أو تصفية القوائم',
        ],
        [
          'Cubit',
          'التحميل والتصفية ومفاتيح الأخطاء والبيانات الجاهزة للعرض',
          'استخدام BuildContext أو استدعاء التنقّل',
        ],
        [
          'مصدر البيانات',
          'الاستعلامات والمعاملات والتحقق ومنع التكرار',
          'الاعتماد على أي شيء من طبقة العرض',
        ],
        ['المستودع', 'التفويض إلى مصدر البيانات', 'احتواء أي منطق'],
        [
          'النموذج',
          'التحويل من وإلى JSON وضبط أنواع التاريخ',
          'إجراء حسابات أو استعلامات',
        ],
      ],
      flex: const [0.9, 1.6, 1.6],
    ),
    heading('قواعد ثابتة في المشروع'),
    bullets(const [
      'كل استعلام SQL يعيش في مصدر بيانات واحد للميزة، ولا يظهر في أي مكان آخر.',
      'فشل أي عملية يتحوّل إلى ApiException يحمل مفتاح ترجمة ثابتًا، فيُترجَم '
          'خطأ قاعدة البيانات مثل أي نص آخر في الواجهة.',
      'كل نص مرئي للمستخدم هو مفتاح في ملفي الترجمة العربي والإنجليزي، '
          'ومعرَّف كثابت في LangKeys.',
      'الاستيرادات داخل مجلد lib نسبية دائمًا، ولا تُستخدم صيغة الحزمة.',
      'جهاز البصمة لا يُفتح له اتصال إلا من zk_device_data_source، ولا شيء '
          'غيره يفتح مقبسًا شبكيًا.',
    ]),
    pw.NewPage(),
    chapter(
      '03',
      'كيف تُقرأ مخططات هذه الوثيقة',
      'رموز الصناديق والخطوط والمفاتيح المستخدمة في الصفحتين التاليتين.',
    ),
    para(
      'المخطط موزّع على صفحتين عرضيتين: الأولى نواة النظام وهي الجداول التي '
      'يراها المستخدم ويحرّرها مباشرة، والثانية الجداول التي تخدم التكامل مع '
      'جهاز البصمة والتقويم والعدّادات. جدول employees يظهر في الصفحتين لأنه '
      'محور الربط في الاثنتين.',
    ),
    table(
      headers: const ['الرمز', 'المعنى', 'أين يظهر'],
      rows: const [
        [
          'PK',
          'المفتاح الأساسي للجدول',
          'أول عمود في كل صندوق، وهو نص معرّف فريد',
        ],
        ['FK', 'مفتاح أجنبي أو رابط إلى جدول آخر', 'employee_id و shift_id'],
        [
          'UQ',
          'قيد تفرّد، مفردًا أو مركّبًا',
          'employee_number و device_user_id والثنائي موظف/تاريخ',
        ],
        [
          'IX',
          'عمود مفهرس لتسريع البحث',
          'is_active و date و is_read ونطاق العطلة',
        ],
        [
          'خط متصل',
          'علاقة مدعومة بقيد مفتاح أجنبي في المخطط نفسه',
          'employees مع attendance_records و permission_requests',
        ],
        [
          'خط متقطّع',
          'علاقة منطقية يفرضها الكود لا المخطط',
          'الوردية والقسم والبصمات والإشعارات',
        ],
        [
          'قدم الغراب',
          'الطرف الذي يقبل عدة سجلات في العلاقة',
          'يُرسم دائمًا عند الجدول التابع',
        ],
        [
          'الشرطة العمودية',
          'الطرف الذي يقبل سجلاً واحدًا',
          'تُرسم دائمًا عند الجدول الأصل',
        ],
      ],
      flex: const [0.8, 1.6, 1.8],
    ),
    callout(
      'لماذا مفتاحان أجنبيان فقط؟',
      'القيد الصريح موجود حيث يكون الحذف المتسلسل مطلوبًا: حذف موظف يجب أن '
          'يمحو حضوره وأذوناته معه. أما الوردية والقسم فمرتبطان منطقيًا لأن '
          'SQLite لا تسمح بإضافة عمود مقيَّد إلى جدول يحمل بيانات فعلية دون إعادة '
          'بنائه كاملًا، وإعادة بناء جدول الموظفين على تثبيت يحمل حضورًا حقيقيًا '
          'مخاطرة أكبر من قيمة القيد. مصادر البيانات تؤدي عمل القيد بدلاً منه: '
          'حذف وردية يحرّر من عليها في المعاملة نفسها.',
      color: gold,
    ),
  ],
);

// ------------------------------------------------------ chapter 03 — core --

const _coreW = 797.0;
const _coreH = 465.0;

/// Orthogonal routes, as (x, y) waypoints measured from the top-left of the
/// diagram area. Kept next to the box coordinates below so a box that moves
/// and a line that does not are obvious.
const _coreSolid = <List<List<double>>>[
  // employees -> attendance_records
  [
    [306, 158],
    [236, 158],
  ],
  // employees -> permission_requests
  [
    [306, 248],
    [272, 248],
    [272, 318],
    [236, 318],
  ],
];

const _coreDashed = <List<List<double>>>[
  // shifts -> employees
  [
    [597, 62],
    [557, 62],
    [557, 138],
    [518, 138],
  ],
  // departments -> employees
  [
    [597, 166],
    [570, 166],
    [570, 198],
    [518, 198],
  ],
];

void _paintCore(PdfGraphics c, PdfPoint size) {
  const h = _coreH;

  c
    ..setLineWidth(0.9)
    ..setStrokeColor(teal)
    ..setLineDashPattern(const <num>[2.5, 2.5]);
  for (final route in _coreDashed) {
    _path(c, h, route);
  }
  c.strokePath();

  c
    ..setLineDashPattern()
    ..setLineWidth(1.1)
    ..setStrokeColor(navy);
  for (final route in _coreSolid) {
    _path(c, h, route);
  }
  c.strokePath();

  // The cardinality marks, always solid so they stay legible on a dashed line.
  c
    ..setLineWidth(1.1)
    ..setStrokeColor(navy);
  _one(c, h, 306, 158, -6);
  _many(c, h, 246, 158, -10);
  _one(c, h, 306, 248, -6);
  _many(c, h, 246, 318, -10);
  c.strokePath();

  c
    ..setLineWidth(1.1)
    ..setStrokeColor(teal);
  _one(c, h, 597, 62, -6);
  _many(c, h, 528, 138, -10);
  _one(c, h, 597, 166, -6);
  _many(c, h, 528, 198, -10);
  c.strokePath();
}

pw.Widget _edgeLabel(String text) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
  color: white,
  child: en(text, size: 6.2, bold: true, color: muted),
);

pw.Page _erdCore() => pw.Page(
  pageTheme: _theme(landscape: true),
  build: (context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      diagramTitle(
        'المخطط العلائقي — نواة النظام',
        'الموظف في المركز: تُشتق منه سجلات الحضور والأذونات بقيد مرجعي صريح '
            'وحذف متسلسل، وتُسند إليه الوردية والقسم برابط منطقي. جدول '
            'الحسابات مستقل علائقيًا ويُشار إليه بالاسم فقط.',
      ),
      pw.SizedBox(height: 8),
      pw.SizedBox(
        width: _coreW,
        height: _coreH,
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: 0,
              top: 0,
              child: pw.SizedBox(
                width: _coreW,
                height: _coreH,
                child: pw.CustomPaint(
                  size: const PdfPoint(_coreW, _coreH),
                  painter: _paintCore,
                ),
              ),
            ),
            pw.Positioned(
              left: 597,
              top: 4,
              child: pw.SizedBox(
                width: 196,
                child: entityBox(
                  name: 'shifts',
                  label: 'الورديات — ساعات العمل المعرَّفة',
                  color: teal,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('name', 'TEXT', 'UQ'),
                    Col('start_work', 'TEXT'),
                    Col('end_work', 'TEXT'),
                    Col('late_grace_minutes', 'INT'),
                    Col('early_out_grace_min', 'INT'),
                    Col('rest_days', 'TEXT'),
                    Col('created_at', 'TEXT'),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 597,
              top: 133,
              child: pw.SizedBox(
                width: 196,
                child: entityBox(
                  name: 'departments',
                  label: 'الأقسام — قائمة الاختيار',
                  color: teal,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('name', 'TEXT', 'UQ'),
                    Col('created_at', 'TEXT'),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 597,
              top: 212,
              child: pw.SizedBox(
                width: 196,
                child: entityBox(
                  name: 'users',
                  label: 'حسابات الدخول المحلية',
                  color: plum,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('email', 'TEXT', 'UQ'),
                    Col('password_hash', 'TEXT'),
                    Col('password_salt', 'TEXT'),
                    Col('display_name', 'TEXT'),
                    Col('role', 'TEXT'),
                    Col('is_active', 'INT'),
                    Col('created_at', 'TEXT'),
                  ],
                  footnote:
                      'مستقل علائقيًا: يُشار إليه بالاسم في corrected_by '
                      'و approved_by و guard_name دون قيد.',
                ),
              ),
            ),
            pw.Positioned(
              left: 306,
              top: 108,
              child: pw.SizedBox(
                width: 212,
                child: entityBox(
                  name: 'employees',
                  label: 'الموظفون — محور النظام كله',
                  color: navy,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('employee_number', 'TEXT', 'UQ'),
                    Col('full_name', 'TEXT'),
                    Col('department', 'TEXT', 'FK'),
                    Col('photo_url', 'TEXT'),
                    Col('has_housing', 'INT'),
                    Col('has_travel_permission', 'INT'),
                    Col('phone', 'TEXT'),
                    Col('position', 'TEXT'),
                    Col('qr_code', 'TEXT'),
                    Col('device_user_id', 'TEXT', 'UQ'),
                    Col('shift_id', 'TEXT', 'FK'),
                    Col('is_active', 'INT', 'IX'),
                    Col('created_at', 'TEXT'),
                    Col('updated_at', 'TEXT'),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 4,
              top: 4,
              child: pw.SizedBox(
                width: 232,
                child: entityBox(
                  name: 'attendance_records',
                  label: 'سجلات الحضور — سجل واحد لكل موظف في اليوم',
                  color: navy,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('employee_id', 'TEXT', 'FK'),
                    Col('date', 'TEXT', 'UQ'),
                    Col('check_in_time', 'TEXT'),
                    Col('check_out_time', 'TEXT'),
                    Col('break_out_time', 'TEXT'),
                    Col('break_in_time', 'TEXT'),
                    Col('breaks', 'TEXT'),
                    Col('overtime_in_time', 'TEXT'),
                    Col('overtime_out_time', 'TEXT'),
                    Col('status', 'TEXT'),
                    Col('notes', 'TEXT'),
                    Col('guard_name', 'TEXT'),
                    Col('is_early_leave', 'INT'),
                    Col('source', 'TEXT'),
                    Col('corrected_at', 'TEXT'),
                    Col('corrected_by', 'TEXT'),
                    Col('created_at', 'TEXT'),
                    Col('updated_at', 'TEXT'),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 4,
              top: 248,
              child: pw.SizedBox(
                width: 232,
                child: entityBox(
                  name: 'permission_requests',
                  label: 'الأذونات — انتداب أو إجازة أو غيرها',
                  color: navy,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('employee_id', 'TEXT', 'FK'),
                    Col('permission_type', 'TEXT'),
                    Col('date', 'TEXT', 'IX'),
                    Col('start_time', 'TEXT'),
                    Col('end_time', 'TEXT'),
                    Col('reason', 'TEXT'),
                    Col('status', 'TEXT'),
                    Col('approved_by', 'TEXT'),
                    Col('notes', 'TEXT'),
                    Col('created_at', 'TEXT'),
                    Col('updated_at', 'TEXT'),
                  ],
                ),
              ),
            ),
            pw.Positioned(left: 524, top: 38, child: _edgeLabel('shift_id')),
            pw.Positioned(left: 522, top: 208, child: _edgeLabel('department')),
            pw.Positioned(
              left: 246,
              top: 140,
              child: _edgeLabel('employee_id'),
            ),
            pw.Positioned(
              left: 240,
              top: 326,
              child: _edgeLabel('employee_id'),
            ),
          ],
        ),
      ),
      pw.Spacer(),
      _diagramLegend(),
    ],
  ),
);

pw.Widget _diagramLegend() => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
  decoration: pw.BoxDecoration(
    color: wash,
    border: pw.Border.all(color: rule, width: 0.5),
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      ar('المفتاح:', size: 7.6, bold: true, color: navy, spacing: 0),
      pw.SizedBox(width: 12),
      legendChip('قيد مفتاح أجنبي في المخطط', navy),
      legendChip('رابط منطقي يفرضه الكود', teal, dashed: true),
      keyChip('PK', 'مفتاح أساسي'),
      keyChip('FK', 'مفتاح أجنبي'),
      keyChip('UQ', 'قيد تفرّد'),
      keyChip('IX', 'عمود مفهرس'),
      pw.Spacer(),
      ar(
        'قدم الغراب = طرف المتعدد · الشرطة = طرف الواحد',
        size: 7.2,
        color: muted,
        spacing: 0,
      ),
    ],
  ),
);

// ---------------------------------------------------- chapter 04 — device --

const _devW = 797.0;
const _devH = 465.0;

const _devDashed = <List<List<double>>>[
  // employees -> device_punches
  [
    [597, 150],
    [558, 150],
    [558, 70],
    [520, 70],
  ],
  // employees -> admin_notifications
  [
    [597, 200],
    [566, 200],
    [566, 300],
    [520, 300],
  ],
  // dismissed_device_users -> device_punches
  [
    [232, 50],
    [300, 50],
  ],
  // pending_employee_matches -> device_punches
  [
    [232, 180],
    [268, 180],
    [268, 110],
    [300, 110],
  ],
];

void _paintDevice(PdfGraphics c, PdfPoint size) {
  const h = _devH;

  c
    ..setLineWidth(0.9)
    ..setStrokeColor(teal)
    ..setLineDashPattern(const <num>[2.5, 2.5]);
  for (final route in _devDashed) {
    _path(c, h, route);
  }
  c.strokePath();

  c
    ..setLineDashPattern()
    ..setLineWidth(1.1)
    ..setStrokeColor(teal);
  _one(c, h, 597, 150, -6);
  _many(c, h, 530, 70, -10);
  _one(c, h, 597, 200, -6);
  _many(c, h, 530, 300, -10);
  _one(c, h, 232, 50, 6);
  _many(c, h, 290, 50, 10);
  _one(c, h, 232, 180, 6);
  _many(c, h, 290, 110, 10);
  c.strokePath();
}

pw.Page _erdDevice() => pw.Page(
  pageTheme: _theme(landscape: true),
  build: (context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      diagramTitle(
        'المخطط العلائقي — تكامل جهاز البصمة والتقويم',
        'الجداول التي لا يحرّرها المستخدم مباشرة: البصمة الخام كما وصلت، '
            'والأسئلة التي علّقتها المزامنة، والتقويم، والعدّادات.',
      ),
      pw.SizedBox(height: 8),
      pw.SizedBox(
        width: _devW,
        height: _devH,
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: 0,
              top: 0,
              child: pw.SizedBox(
                width: _devW,
                height: _devH,
                child: pw.CustomPaint(
                  size: const PdfPoint(_devW, _devH),
                  painter: _paintDevice,
                ),
              ),
            ),
            pw.Positioned(
              left: 597,
              top: 120,
              child: pw.SizedBox(
                width: 196,
                child: entityBox(
                  name: 'employees',
                  label: 'الموظفون — معروض مختصرًا',
                  color: navy,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('full_name', 'TEXT'),
                    Col('device_user_id', 'TEXT', 'UQ'),
                    Col('shift_id', 'TEXT', 'FK'),
                    Col('is_active', 'INT', 'IX'),
                  ],
                  footnote:
                      'العمود device_user_id هو معرّف المستخدم على '
                      'الجهاز، لا رقم فتحة التسجيل.',
                ),
              ),
            ),
            pw.Positioned(
              left: 597,
              top: 300,
              child: pw.SizedBox(
                width: 196,
                child: entityBox(
                  name: 'app_sequences',
                  label: 'العدّادات المتصاعدة',
                  color: gold,
                  columns: const [
                    Col('name', 'TEXT', 'PK'),
                    Col('value', 'INT'),
                  ],
                  footnote:
                      'جدول مستقل. يضمن ألا يُعاد إصدار رقم وظيفي بعد '
                      'حذف صاحبه.',
                ),
              ),
            ),
            pw.Positioned(
              left: 300,
              top: 20,
              child: pw.SizedBox(
                width: 220,
                child: entityBox(
                  name: 'device_punches',
                  label: 'البصمات الخام كما أرسلها الجهاز',
                  color: navy,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('device_user_id', 'TEXT', 'UQ'),
                    Col('punch_time', 'TEXT', 'UQ'),
                    Col('state', 'INT'),
                    Col('type', 'INT'),
                    Col('employee_id', 'TEXT', 'FK'),
                    Col('synced_at', 'TEXT'),
                  ],
                  footnote:
                      'التفرّد على الثنائي device_user_id + punch_time '
                      'هو ما يجعل إعادة المزامنة بلا تكرار.',
                ),
              ),
            ),
            pw.Positioned(
              left: 300,
              top: 230,
              child: pw.SizedBox(
                width: 220,
                child: entityBox(
                  name: 'admin_notifications',
                  label: 'إشعارات المدير — تنبيهات مُولَّدة',
                  color: navy,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('type', 'TEXT'),
                    Col('employee_id', 'TEXT', 'FK'),
                    Col('employee_name', 'TEXT'),
                    Col('message', 'TEXT'),
                    Col('date', 'TEXT'),
                    Col('early_leave_count', 'INT'),
                    Col('is_read', 'INT', 'IX'),
                    Col('created_at', 'TEXT'),
                  ],
                  footnote:
                      'اسم الموظف مكرَّر هنا عمدًا ليبقى الإشعار مقروءًا '
                      'بعد حذف صاحبه.',
                ),
              ),
            ),
            pw.Positioned(
              left: 4,
              top: 14,
              child: pw.SizedBox(
                width: 228,
                child: entityBox(
                  name: 'dismissed_device_users',
                  label: 'مستخدمو الجهاز الذين حذفهم المدير',
                  color: plum,
                  columns: const [
                    Col('device_user_id', 'TEXT', 'PK'),
                    Col('dismissed_at', 'TEXT'),
                    Col('removed_from_device', 'INT'),
                  ],
                  footnote:
                      'بدونه تُعيد المزامنة التالية إنشاء الموظف '
                      'المحذوف، لأنه ما زال مسجَّلاً على الجهاز.',
                ),
              ),
            ),
            pw.Positioned(
              left: 4,
              top: 140,
              child: pw.SizedBox(
                width: 228,
                child: entityBox(
                  name: 'pending_employee_matches',
                  label: 'مطابقات معلّقة بانتظار قرار المدير',
                  color: plum,
                  columns: const [
                    Col('device_user_id', 'TEXT', 'PK'),
                    Col('device_name', 'TEXT'),
                    Col('detected_at', 'TEXT'),
                  ],
                  footnote:
                      'يُسجَّل السؤال فقط. الإجابة المحتملة تُحسب من '
                      'جديد عند كل مراجعة.',
                ),
              ),
            ),
            pw.Positioned(
              left: 4,
              top: 270,
              child: pw.SizedBox(
                width: 228,
                child: entityBox(
                  name: 'holidays',
                  label: 'العطلات الرسمية على مستوى المنشأة',
                  color: gold,
                  columns: const [
                    Col('id', 'TEXT', 'PK'),
                    Col('name', 'TEXT'),
                    Col('start_date', 'TEXT', 'IX'),
                    Col('end_date', 'TEXT', 'IX'),
                    Col('is_paid', 'INT'),
                    Col('created_at', 'TEXT'),
                  ],
                  footnote:
                      'جدول مستقل. العطلة خاصية للتاريخ نفسه، بينما يوم '
                      'الراحة خاصية للوردية.',
                ),
              ),
            ),
            pw.Positioned(
              left: 524,
              top: 176,
              child: _edgeLabel('employee_id'),
            ),
            pw.Positioned(
              left: 524,
              top: 318,
              child: _edgeLabel('employee_id'),
            ),
            pw.Positioned(
              left: 238,
              top: 32,
              child: _edgeLabel('device_user_id'),
            ),
            pw.Positioned(
              left: 238,
              top: 234,
              child: _edgeLabel('device_user_id'),
            ),
          ],
        ),
      ),
      pw.Spacer(),
      _diagramLegend(),
    ],
  ),
);

// -------------------------------------------------- chapters 05 .. 12 -----

/// One entry of the data dictionary: the table's name, what it is for, and
/// every column it holds.
List<pw.Widget> _dict(
  String name,
  String label,
  String intro,
  List<List<String>> rows,
) => [
  pw.SizedBox(height: 12),
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(9, 6, 9, 6),
        decoration: pw.BoxDecoration(
          color: navy,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(4),
            topRight: pw.Radius.circular(4),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            en(name, size: 10, bold: true, color: white),
            pw.SizedBox(width: 8),
            pw.Container(width: 1, height: 10, color: gold),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: ar(
                label,
                size: 8.6,
                color: PdfColors.blueGrey100,
                spacing: 0,
              ),
            ),
          ],
        ),
      ),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(9, 6, 9, 7),
        decoration: const pw.BoxDecoration(
          color: wash,
          border: pw.Border(
            left: pw.BorderSide(color: rule, width: 0.5),
            right: pw.BorderSide(color: rule, width: 0.5),
          ),
        ),
        child: ar(intro, size: 8.8, align: pw.TextAlign.justify, spacing: 2.4),
      ),
    ],
  ),
  // Kept outside the column above so a long dictionary can break across
  // pages instead of pushing a half-empty page ahead of it.
  table(
    headers: const ['العمود', 'النوع', 'القيد', 'الوصف'],
    rows: rows,
    flex: const [1.35, 0.55, 0.7, 2.6],
    latin: const [true, true, true, false],
    fontSize: 7.9,
    headerColor: navySoft,
  ),
];

pw.MultiPage _partTwo() => pw.MultiPage(
  pageTheme: _theme(),
  header: (context) => _runningHeader('قاموس البيانات والتفاصيل'),
  footer: _runningFooter,
  build: (context) => [
    chapter(
      '05',
      'قاموس البيانات',
      'كل جدول في المخطط، وكل عمود فيه، والغرض الذي أُنشئ من أجله.',
    ),
    para(
      'المعرّفات في هذا المخطط نصية وليست أعدادًا متصاعدة: يولّدها التطبيق '
      'قبل الكتابة عبر DbId، فلا يحتاج السطر إلى العودة من قاعدة البيانات كي '
      'يُعرف رقمه. التواريخ والأوقات تُخزَّن نصًا بصيغة ISO 8601، والقيم '
      'المنطقية تُخزَّن عددًا صحيحًا 0 أو 1، وهو السلوك الطبيعي لـ SQLite '
      'التي لا تملك نوعًا منطقيًا ولا نوعًا زمنيًا مستقلاً.',
    ),

    ..._dict(
      'users',
      'حسابات الدخول المحلية',
      'الحساب الذي يفتح به الموظف أو المدير التطبيق على هذا الجهاز. حلّ محل '
          'جدول المستخدمين في النسخة القديمة التي كانت تعمل بخادم ورموز JWT: '
          'تثبيت على جهاز واحد لا يحتاج أكثر من تجزئة كلمة مرور ودور.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف نصي يولّده التطبيق قبل الإدراج.'],
        [
          'email',
          'TEXT',
          'UQ',
          'البريد المستخدم للدخول. المقارنة تتجاهل حالة الأحرف بفضل '
              'COLLATE NOCASE، فلا يمكن تسجيل حسابين بالبريد نفسه بصيغتين.',
        ],
        [
          'password_hash',
          'TEXT',
          '',
          'ناتج التجزئة، لا كلمة المرور. لا تُخزَّن كلمة المرور في أي مكان.',
        ],
        [
          'password_salt',
          'TEXT',
          '',
          'ملح عشوائي لكل حساب، يمنع أن تُعطي كلمتا مرور متطابقتان التجزئة '
              'نفسها.',
        ],
        [
          'display_name',
          'TEXT',
          '',
          'الاسم المعروض في الواجهة، وقد يكون فارغًا.',
        ],
        [
          'role',
          'TEXT',
          '',
          'الدور: admin أو guard. القيمة الافتراضية guard، ولا يُمنح دور '
              'المدير ضمنًا.',
        ],
        [
          'is_active',
          'INT',
          '',
          'تعطيل الحساب دون حذفه، فتبقى الإشارات التاريخية إلى اسمه مفهومة.',
        ],
        ['created_at', 'TEXT', '', 'تاريخ إنشاء الحساب بصيغة ISO 8601.'],
      ],
    ),

    ..._dict(
      'employees',
      'الموظفون — الجدول المحوري',
      'كل شيء آخر في المخطط تقريبًا يشير إلى هذا الجدول. يُنشأ السطر إما يدويًا '
          'من شاشة الموظفين، أو تلقائيًا عند المزامنة لمن هو مسجَّل على الجهاز ولم '
          'يُضَف بعد، أو دفعةً واحدة من ملف Excel.',
      const [
        ['id', 'TEXT', 'PK', 'المعرّف الذي تشير إليه سجلات الحضور والأذونات.'],
        [
          'employee_number',
          'TEXT',
          'UQ',
          'الرقم الوظيفي. فريد جزئيًا: القيد يسري على القيم غير الفارغة فقط، '
              'فيمكن أن يوجد أكثر من موظف بلا رقم. يُشتق الرقم من عدّاد '
              'app_sequences لا من أكبر قيمة موجودة.',
        ],
        ['full_name', 'TEXT', '', 'الاسم الكامل كما يظهر في كل تقرير.'],
        [
          'department',
          'TEXT',
          'FK',
          'اسم القسم نصًا لا معرّفًا. رابط منطقي إلى جدول departments بلا قيد، '
              'لأن كل تقرير وتصدير وتصفية في التطبيق يقرأ القسم بهذه الصورة.',
        ],
        [
          'photo_url',
          'TEXT',
          '',
          'مسار صورة الموظف على القرص، وقد يكون فارغًا.',
        ],
        [
          'has_housing',
          'INT',
          '',
          'هل الموظف مقيم في سكن المنشأة. يغيّر قواعد تقييم اليوم في طيّ '
              'البصمات.',
        ],
        [
          'has_travel_permission',
          'INT',
          '',
          'هل يملك انتدابًا دائمًا. يُستخدم في قاعدة الخميس تحديدًا.',
        ],
        ['phone', 'TEXT', '', 'رقم الهاتف، اختياري.'],
        ['position', 'TEXT', '', 'المسمّى الوظيفي، اختياري.'],
        ['qr_code', 'TEXT', '', 'رمز بديل للتعريف عند الحاجة، اختياري.'],
        [
          'device_user_id',
          'TEXT',
          'UQ',
          'معرّف المستخدم على جهاز البصمة. فريد جزئيًا كي لا يدّعي موظفان '
              'التسجيل نفسه. مهم: هذا هو userId الذي تحمله سجلات البصمة، وليس '
              'uid وهو رقم فتحة التسجيل، والرقمان مختلفان.',
        ],
        [
          'shift_id',
          'TEXT',
          'FK',
          'الوردية التي يُحاسب عليها. القيمة الفارغة تعني ورديّة المنشأة '
              'الافتراضية من إعدادات ساعات العمل، وهو حال كل موظف قبل إضافة '
              'الورديات.',
        ],
        [
          'is_active',
          'INT',
          'IX',
          'مفهرس لأن كل شاشة تقريبًا تبدأ بتصفية الموظفين النشطين.',
        ],
        ['created_at', 'TEXT', '', 'تاريخ الإنشاء.'],
        ['updated_at', 'TEXT', '', 'تاريخ آخر تعديل.'],
      ],
    ),

    ..._dict(
      'attendance_records',
      'سجلات الحضور اليومية',
      'سطر واحد لكل موظف في كل يوم، يفرضه فهرس فريد على الثنائي موظف/تاريخ. '
          'هذا القيد بالذات هو ما يجعل مزامنة الجهاز عملية قابلة للتكرار: إعادة '
          'المزامنة توسّع السطر القائم ولا تنشئ سطرًا ثانيًا.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف السجل.'],
        [
          'employee_id',
          'TEXT',
          'FK',
          'مفتاح أجنبي صريح إلى employees مع حذف متسلسل: حذف الموظف يمحو '
              'حضوره كله في المعاملة نفسها.',
        ],
        [
          'date',
          'TEXT',
          'UQ',
          'تاريخ اليوم. يشكّل مع employee_id الفهرس الفريد، ومفهرس وحده أيضًا '
              'لأن تقارير الشهر تبدأ بنطاق تواريخ.',
        ],
        [
          'check_in_time',
          'TEXT',
          '',
          'وقت الحضور، من وضع البصمة 0 أو إدخال يدوي.',
        ],
        ['check_out_time', 'TEXT', '', 'وقت الانصراف، من وضع البصمة 1.'],
        [
          'break_out_time',
          'TEXT',
          '',
          'أول خروج استراحة في اليوم، وهو ملخّص لا سجل كامل.',
        ],
        ['break_in_time', 'TEXT', '', 'آخر عودة من استراحة في اليوم.'],
        [
          'breaks',
          'TEXT',
          '',
          'كل استراحات اليوم مصفوفةً بصيغة JSON من أزواج خروج/عودة. أُضيف في '
              'الإصدار الخامس لأن العمودين أعلاه يفقدان ما بين أول خروج وآخر '
              'عودة.',
        ],
        [
          'overtime_in_time',
          'TEXT',
          '',
          'بداية العمل الإضافي، من وضع البصمة 4.',
        ],
        [
          'overtime_out_time',
          'TEXT',
          '',
          'نهاية العمل الإضافي، من وضع البصمة 5.',
        ],
        [
          'status',
          'TEXT',
          '',
          'تقييم اليوم: present أو late أو early_leave أو travel_permission أو '
              'absent، والقيمة الابتدائية pending.',
        ],
        ['notes', 'TEXT', '', 'ملاحظة يكتبها المدير، ولا تمسّها المزامنة.'],
        [
          'guard_name',
          'TEXT',
          '',
          'اسم من سجّل الحضور يدويًا. يشير إلى users بالاسم لا بقيد.',
        ],
        ['is_early_leave', 'INT', '', 'علامة انصراف مبكر، تُحسب عند الطيّ.'],
        [
          'source',
          'TEXT',
          '',
          'من أين جاء السجل: manual أو device. الافتراضي manual، وهو ما يحمي '
              'الإدخال اليدوي من أن تدهسه مزامنة لاحقة.',
        ],
        [
          'corrected_at',
          'TEXT',
          '',
          'وقت التصحيح الوحيد المسموح به في اليوم نفسه. وجوده إيصال بأن '
              'التصحيح استُهلك، وقفل يمنع طيّ الجهاز من لمس اليوم.',
        ],
        ['corrected_by', 'TEXT', '', 'اسم المدير الذي أجرى التصحيح.'],
        ['created_at', 'TEXT', '', 'تاريخ الإنشاء.'],
        ['updated_at', 'TEXT', '', 'تاريخ آخر تعديل.'],
      ],
    ),

    ..._dict(
      'permission_requests',
      'الأذونات والانتدابات والإجازات',
      'ما يبرّر غياب الموظف أو خروجه، ويؤخذ في الحسبان عند تقييم اليوم. الحالة '
          'الافتراضية approved لأن المدير هو من يُدخل الإذن أصلًا، فلا توجد دورة '
          'موافقة تنتظر أحدًا.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف الإذن.'],
        [
          'employee_id',
          'TEXT',
          'FK',
          'مفتاح أجنبي صريح إلى employees مع حذف متسلسل.',
        ],
        [
          'permission_type',
          'TEXT',
          '',
          'النوع: travel_permission أو vacation أو other.',
        ],
        [
          'date',
          'TEXT',
          'IX',
          'تاريخ الإذن. مفهرس وحده، وضمن فهرس ثلاثي مع الموظف والنوع.',
        ],
        ['start_time', 'TEXT', '', 'بداية الإذن إن كان جزئيًا خلال اليوم.'],
        ['end_time', 'TEXT', '', 'نهاية الإذن الجزئي.'],
        ['reason', 'TEXT', '', 'سبب الإذن كما كُتب.'],
        ['status', 'TEXT', '', 'الحالة، والافتراضي approved.'],
        [
          'approved_by',
          'TEXT',
          '',
          'اسم من اعتمد الإذن. إشارة بالاسم إلى users لا قيدًا مرجعيًا.',
        ],
        ['notes', 'TEXT', '', 'ملاحظة إضافية.'],
        ['created_at', 'TEXT', '', 'تاريخ الإنشاء.'],
        ['updated_at', 'TEXT', '', 'تاريخ آخر تعديل.'],
      ],
    ),

    ..._dict(
      'shifts',
      'الورديات — ساعات العمل المعرَّفة',
      'أُضيف في الإصدار التاسع كي تُحاسَب كل مجموعة على ساعاتها بدل زوج أوقات '
          'واحد للمنشأة كلها. السماحان بالدقائق لا بالتوقيت، لأن المدير يحدّد كم '
          'تأخيرًا وكم انصرافًا مبكرًا تتسامح معه الوردية.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف الوردية.'],
        [
          'name',
          'TEXT',
          'UQ',
          'اسم الوردية، فريد بتجاهل حالة الأحرف، لأن الاسم هو ما يميّزها في '
              'قائمة اختيار الموظف.',
        ],
        ['start_work', 'TEXT', '', 'وقت بدء الدوام.'],
        ['end_work', 'TEXT', '', 'وقت انتهاء الدوام.'],
        ['late_grace_minutes', 'INT', '', 'دقائق التأخير المتسامح معها.'],
        [
          'early_out_grace_minutes',
          'INT',
          '',
          'دقائق الانصراف المبكر المتسامح معها.',
        ],
        [
          'rest_days',
          'TEXT',
          '',
          'أيام الراحة بأرقام أيام الأسبوع مفصولة بفواصل: القيمة 5,6 تعني '
              'الجمعة والسبت. القيمة الفارغة تعني أن الوردية تعمل كل يوم.',
        ],
        ['created_at', 'TEXT', '', 'تاريخ الإنشاء.'],
      ],
    ),

    ..._dict(
      'departments',
      'الأقسام — قائمة الاختيار التي يديرها المدير',
      'هذا الجدول هو الكتالوج الذي تعرضه قائمة اختيار القسم. مصدر بياناته '
          'يوحّده مع الأقسام المستخدمة فعليًا في جدول الموظفين، فلا يمكن أن يختفي '
          'قسم من تحت أقدام من يقفون فيه.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف القسم.'],
        [
          'name',
          'TEXT',
          'UQ',
          'اسم القسم، فريد بتجاهل حالة الأحرف كي لا تنقسم إحصاءات قسم واحد '
              'بين إملاءين.',
        ],
        ['created_at', 'TEXT', '', 'تاريخ الإنشاء.'],
      ],
    ),

    ..._dict(
      'holidays',
      'العطلات الرسمية على مستوى المنشأة',
      'نطاق تاريخي لا تاريخ مفرد، لأن العطلات التي تهم هنا تأتي متتابعة: العيد '
          'أيام، وإغلاق المنشأة قد يكون أسبوعًا. إدخال سطر لكل يوم كان سيكون '
          'مُملًّا بما يكفي ليُهمَل، وتقويم بثغرات أسوأ من غياب التقويم.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف العطلة.'],
        ['name', 'TEXT', '', 'اسم العطلة كما يظهر في التقويم.'],
        ['start_date', 'TEXT', 'IX', 'أول يوم في النطاق.'],
        ['end_date', 'TEXT', 'IX', 'آخر يوم في النطاق، شاملًا.'],
        ['is_paid', 'INT', '', 'هل العطلة مدفوعة. الافتراضي نعم.'],
        ['created_at', 'TEXT', '', 'تاريخ الإنشاء.'],
      ],
    ),

    ..._dict(
      'device_punches',
      'البصمات الخام كما أرسلها الجهاز',
      'تُحفظ البصمة حرفيًا كما وصلت، قبل أي تفسير. هذا ما يجعل إعادة المزامنة '
          'آمنة، ويسمح بإعادة طيّ بصمات موظف رُبط بالجهاز متأخرًا دون العودة إلى '
          'الجهاز مرة أخرى.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف البصمة داخل التطبيق.'],
        [
          'device_user_id',
          'TEXT',
          'UQ',
          'معرّف المستخدم على الجهاز. يشكّل مع وقت البصمة مفتاح منع التكرار.',
        ],
        [
          'punch_time',
          'TEXT',
          'UQ',
          'وقت البصمة كما سجّله الجهاز. مفهرس وحده أيضًا لأن التقارير تبدأ '
              'بنطاق زمني.',
        ],
        [
          'state',
          'INT',
          '',
          'وضع البصمة الذي اختاره المستخدم على لوحة المفاتيح، من 0 إلى 5.',
        ],
        ['type', 'INT', '', 'نوع التحقق: بصمة أو بطاقة أو كلمة مرور.'],
        [
          'employee_id',
          'TEXT',
          'FK',
          'الموظف المرتبط، إن وُجد. يبقى فارغًا لبصمات معرّف لم يُربط بأحد '
              'بعد، ولا تُهمل هذه البصمات بل تنتظر.',
        ],
        ['synced_at', 'TEXT', '', 'وقت سحب البصمة من الجهاز إلى التطبيق.'],
      ],
    ),

    ..._dict(
      'admin_notifications',
      'إشعارات المدير',
      'تنبيهات يولّدها التطبيق، مثل تجاوز الموظف حدّ مرات الانصراف المبكر. '
          'الاسم مكرَّر داخل الإشعار عمدًا: لا يوجد قيد مرجعي هنا، فيبقى الإشعار '
          'مقروءًا حتى بعد حذف الموظف.',
      const [
        ['id', 'TEXT', 'PK', 'معرّف الإشعار.'],
        [
          'type',
          'TEXT',
          '',
          'نوع التنبيه، مثل early_leave_threshold، ويُستخدم في تصنيف العرض.',
        ],
        ['employee_id', 'TEXT', 'FK', 'الموظف المعني. رابط منطقي بلا قيد.'],
        [
          'employee_name',
          'TEXT',
          '',
          'الاسم منسوخًا وقت التوليد، فلا يتغيّر الإشعار بتغيّر السجل.',
        ],
        ['message', 'TEXT', '', 'نص الرسالة الجاهز للعرض.'],
        ['date', 'TEXT', '', 'التاريخ الذي يخصّه الإشعار.'],
        [
          'early_leave_count',
          'INT',
          '',
          'عدد مرات الانصراف المبكر التي أطلقت التنبيه.',
        ],
        [
          'is_read',
          'INT',
          'IX',
          'مفهرس لأن شارة الإشعارات تسأل عن غير المقروء في كل فتح للشاشة.',
        ],
        ['created_at', 'TEXT', '', 'وقت التوليد.'],
      ],
    ),

    ..._dict(
      'dismissed_device_users',
      'مستخدمو الجهاز الذين حذفهم المدير',
      'بدون هذا الجدول تُلغي المزامنة التالية عملية الحذف: الشخص ما زال مسجَّلاً '
          'على الجهاز، فيعيد استيراد الموظفين إنشاءه من جديد.',
      const [
        ['device_user_id', 'TEXT', 'PK', 'معرّف المستخدم على الجهاز.'],
        ['dismissed_at', 'TEXT', '', 'وقت الحذف من التطبيق.'],
        [
          'removed_from_device',
          'INT',
          '',
          'هل حُذف من الجهاز نفسه أيضًا، أم من التطبيق فقط.',
        ],
      ],
    ),

    ..._dict(
      'pending_employee_matches',
      'مطابقات معلّقة بانتظار قرار المدير',
      'حين يصل من الجهاز مستخدم يشبه اسمه شخصًا موجودًا على الملف، يتوقف '
          'الاستيراد ويكتب السؤال بدل أن يخمّن. التخمين الخاطئ هنا ليس سطرًا '
          'مكرّرًا، بل حضور شخص يُقيَّد باسم شخص آخر، ولا شيء لاحقًا يستطيع كشف ذلك.',
      const [
        ['device_user_id', 'TEXT', 'PK', 'معرّف المستخدم على الجهاز.'],
        ['device_name', 'TEXT', '', 'الاسم كما يكتبه الجهاز.'],
        [
          'detected_at',
          'TEXT',
          '',
          'وقت رصد التشابه. الإجابة المحتملة لا تُخزَّن، بل تُحسب من جديد عند '
              'كل مراجعة كي لا يُقترح موظف حُذف أو رُبط يدويًا في الأثناء.',
        ],
      ],
    ),

    ..._dict(
      'app_sequences',
      'العدّادات المتصاعدة',
      'رقم وظيفي مشتق من أكبر قيمة موجودة كان سيُعاد إصداره فور حذف صاحبه، '
          'فيشير مرجع رواتب قديم إلى شخص آخر دون أن ينبّه أحدًا.',
      const [
        ['name', 'TEXT', 'PK', 'اسم العدّاد، مثل employee_number.'],
        ['value', 'INT', '', 'آخر قيمة أُصدرت. لا تنقص أبدًا.'],
      ],
    ),

    pw.NewPage(),
    chapter(
      '06',
      'العلاقات والقيود المرجعية',
      'ما يفرضه المخطط بنفسه، وما يفرضه الكود نيابةً عنه.',
    ),
    para(
      'المفاتيح الأجنبية مفعّلة صراحةً في كل اتصال عبر الأمر '
      'PRAGMA foreign_keys، لأنها معطّلة افتراضيًا في SQLite. وبدون هذا '
      'السطر يترك حذفُ الموظف سجلات حضور يتيمة بصمت.',
    ),
    table(
      headers: const [
        'العلاقة — الأصل ثم التابع',
        'النوع',
        'العمود الرابط',
        'عند الحذف',
        'ملاحظة',
      ],
      rows: const [
        [
          'employees → attendance_records',
          'واحد لمتعدد',
          'employee_id',
          'حذف متسلسل',
          'قيد صريح في المخطط.',
        ],
        [
          'employees → permission_requests',
          'واحد لمتعدد',
          'employee_id',
          'حذف متسلسل',
          'قيد صريح في المخطط.',
        ],
        [
          'shifts → employees',
          'واحد لمتعدد',
          'shift_id',
          'يفرضه الكود',
          'حذف الوردية يحرّر من عليها في المعاملة نفسها.',
        ],
        [
          'departments → employees',
          'واحد لمتعدد',
          'department',
          'يفرضه الكود',
          'القسم مخزَّن كاسم لأن كل التقارير تقرؤه هكذا.',
        ],
        [
          'employees → device_punches',
          'واحد لمتعدد',
          'employee_id',
          'يبقى السطر',
          'البصمة تبقى ولو لم يُربط أحد بها بعد.',
        ],
        [
          'employees ↔ device_punches',
          'واحد لواحد',
          'device_user_id',
          'يفرضه الكود',
          'الرابط الحقيقي مع الجهاز، ومنه يُشتق employee_id.',
        ],
        [
          'employees → admin_notifications',
          'واحد لمتعدد',
          'employee_id',
          'يبقى السطر',
          'الاسم منسوخ داخل الإشعار كي يبقى مفهومًا.',
        ],
        [
          'device_punches ↔ dismissed_device_users',
          'منطقية',
          'device_user_id',
          'يفرضه الكود',
          'قائمة منع تحمي الحذف من المزامنة التالية.',
        ],
        [
          'device_punches ↔ pending_employee_matches',
          'منطقية',
          'device_user_id',
          'يفرضه الكود',
          'سؤال مؤجَّل بانتظار قرار بشري.',
        ],
        [
          'users ↔ attendance_records',
          'إشارة بالاسم',
          'corrected_by · guard_name',
          'لا أثر',
          'نص حرّ للسجل التاريخي، لا مفتاح.',
        ],
        [
          'users ↔ permission_requests',
          'إشارة بالاسم',
          'approved_by',
          'لا أثر',
          'نص حرّ كذلك.',
        ],
        [
          'holidays · app_sequences',
          'مستقلان',
          '—',
          '—',
          'لا يرتبطان بأي جدول آخر.',
        ],
      ],
      flex: const [1.9, 0.85, 1.25, 0.8, 2.0],
      latin: const [true, false, true, false, false],
      fontSize: 7.7,
    ),
    callout(
      'قاعدة السطر الواحد في اليوم',
      'الفهرس الفريد على الثنائي employee_id و date هو أهم قيد في المخطط كله. '
          'الجهاز يعيد ذاكرته كاملة في كل قراءة، فبدون هذا القيد كانت كل مزامنة '
          'ستضيف نسخة جديدة من اليوم نفسه. وجوده يحوّل عملية الطيّ من إضافة إلى '
          'توسيع: أبكر حضور وأحدث انصراف يفوزان، والملاحظات واسم المسجّل تبقى '
          'كما هي.',
      color: navy,
    ),

    pw.NewPage(),
    chapter(
      '07',
      'الفهارس وقيود التفرّد',
      'سبعة عشر فهرسًا، ولكل منها سبب محدَّد.',
    ),
    table(
      headers: const ['الفهرس', 'الجدول والأعمدة', 'فريد', 'الغرض'],
      rows: const [
        ['ix_users_email', 'users (email)', 'نعم', 'منع حسابين بالبريد نفسه.'],
        [
          'ix_employees_number',
          'employees (employee_number)',
          'جزئي',
          'يسري على القيم غير الفارغة فقط.',
        ],
        [
          'ix_employees_device_user',
          'employees (device_user_id)',
          'جزئي',
          'منع موظفين من ادّعاء التسجيل نفسه على الجهاز.',
        ],
        [
          'ix_employees_active',
          'employees (is_active)',
          'لا',
          'كل شاشة تبدأ بتصفية النشطين.',
        ],
        [
          'ix_employees_shift',
          'employees (shift_id)',
          'لا',
          'التقارير تعدّ من على كل وردية، والطيّ يبحث عنها لكل يوم موظف.',
        ],
        [
          'ix_attendance_employee_date',
          'attendance_records (employee_id, date)',
          'نعم',
          'سطر واحد لكل موظف في اليوم، وهو أساس تكرار المزامنة بأمان.',
        ],
        [
          'ix_attendance_date',
          'attendance_records (date)',
          'لا',
          'تقارير الشهر والنطاقات الزمنية.',
        ],
        [
          'ix_permissions_employee_date_type',
          'permission_requests (employee_id, date, permission_type)',
          'لا',
          'السؤال المتكرر: هل لهذا الموظف إذن من هذا النوع في هذا اليوم.',
        ],
        [
          'ix_permissions_date',
          'permission_requests (date)',
          'لا',
          'عرض أذونات يوم أو شهر.',
        ],
        [
          'ix_notifications_read',
          'admin_notifications (is_read)',
          'لا',
          'شارة غير المقروء في كل فتح للتطبيق.',
        ],
        [
          'ix_notifications_employee_type_date',
          'admin_notifications (employee_id, type, date)',
          'لا',
          'منع تكرار التنبيه نفسه لليوم نفسه.',
        ],
        [
          'ix_punch_unique',
          'device_punches (device_user_id, punch_time)',
          'نعم',
          'مفتاح منع التكرار للبصمة الخام.',
        ],
        [
          'ix_punch_time',
          'device_punches (punch_time)',
          'لا',
          'تقرير البصمات بنطاق زمني.',
        ],
        [
          'ix_punch_employee',
          'device_punches (employee_id)',
          'لا',
          'إعادة طيّ بصمات موظف بعينه.',
        ],
        [
          'ix_departments_name',
          'departments (name COLLATE NOCASE)',
          'نعم',
          'منع انقسام إحصاءات قسم واحد بين إملاءين.',
        ],
        [
          'ix_shifts_name',
          'shifts (name COLLATE NOCASE)',
          'نعم',
          'الاسم هو ما يميّز الوردية في قائمة الاختيار.',
        ],
        [
          'ix_holidays_range',
          'holidays (start_date, end_date)',
          'لا',
          'كل شاشة تقيّم شهرًا تسأل عن عطلات نطاقه.',
        ],
      ],
      flex: const [2.0, 2.0, 0.45, 1.95],
      latin: const [true, true, false, false],
      fontSize: 7.5,
    ),

    pw.NewPage(),
    chapter(
      '08',
      'تطوّر المخطط عبر الإصدارات',
      'عشرة إصدارات، كلها ترقية في المكان دون إعادة إنشاء قاعدة البيانات.',
    ),
    para(
      'التثبيتات القائمة تحمل حضورًا حقيقيًا، فكل تغيير في المخطط يُطبَّق '
      'بالترقية لا بإعادة البناء. دالة الترقية تقارن الإصدار القديم بالجديد '
      'وتنفّذ ما ينقص فقط، فتصل قاعدة بيانات من الإصدار الأول إلى العاشر '
      'بالمرور على كل الخطوات بالترتيب.',
    ),
    table(
      headers: const ['الإصدار', 'ما أُضيف', 'السبب'],
      rows: const [
        [
          'v1',
          'المخطط الأساسي: الحسابات، الموظفون، الحضور، الأذونات، الإشعارات، '
              'البصمات الخام',
          'النواة الأولى بعد الانتقال من الخادم إلى التخزين المحلي.',
        ],
        [
          'v2',
          'أعمدة الاستراحة والعمل الإضافي الأربعة في سجل الحضور',
          'الجهاز يرسل ستة أوضاع للبصمة، والإصدار الأول كان يتسع لاثنين فقط.',
        ],
        [
          'v3',
          'جدول dismissed_device_users',
          'بدونه تُعيد المزامنة إنشاء الموظف الذي حذفه المدير للتو.',
        ],
        [
          'v4',
          'جدول app_sequences وتعبئة عدّاد الرقم الوظيفي',
          'كي لا يُعاد إصدار رقم وظيفي بعد حذف صاحبه.',
        ],
        [
          'v5',
          'العمود breaks في سجل الحضور',
          'ليحمل اليوم كل استراحاته لا أول خروج وآخر عودة فقط.',
        ],
        [
          'v6',
          'العمودان corrected_at و corrected_by',
          'إيصال التصحيح الوحيد المسموح به في اليوم نفسه، وقفل يمنع الطيّ من '
              'لمس اليوم بعده.',
        ],
        [
          'v7',
          'جدول pending_employee_matches',
          'كي ينتظر مستخدمُ جهازٍ يشبه اسمه موظفًا قائمًا قرارَ المدير بدل أن '
              'يصير نسخة ثانية منه.',
        ],
        [
          'v8',
          'جدول departments وفهرس اسمه، مع تعبئته من الأقسام المستخدمة',
          'ليختار المدير القسم من قائمة يديرها بدل إعادة كتابته في كل مرة. '
              'التعبئة ضرورية وإلا فُتحت قائمة فارغة وموظفون تحت أسماء لا '
              'تعرضها.',
        ],
        [
          'v9',
          'جدول shifts والعمود shift_id وفهرسه',
          'لتُحاسَب كل مجموعة على ساعاتها. لم يُنقل أحد إلى وردية بالترقية: '
              'القيمة الفارغة تعني الافتراضي، فيتصرف التثبيت القديم كما كان '
              'تمامًا.',
        ],
        [
          'v10',
          'جدول holidays وفهرس نطاقه، والعمود rest_days في الورديات',
          'ليعرف التطبيق التواريخ التي لم يكن أحد مطالبًا بالعمل فيها بدل '
              'معاملة كل يوم في التقويم كيوم عمل.',
        ],
      ],
      flex: const [0.45, 2.0, 2.6],
      latin: const [true, false, false],
      fontSize: 7.8,
    ),

    pw.NewPage(),
    chapter(
      '09',
      'دورة حياة البيانات',
      'من ضغطة الإصبع على الجهاز حتى سجل حضور يومي مُقيَّم.',
    ),
    heading('أوضاع البصمة الستة'),
    para(
      'يختار الموظف الوضع على لوحة مفاتيح الجهاز قبل أن يضع إصبعه، وكل وضع '
      'يملأ عموده الخاص. أوضاع الدخول تأخذ أبكر بصمة، وأوضاع الخروج تأخذ '
      'أحدثها، فتنطوي الاستراحات المتكررة إلى أول خروج وآخر عودة.',
    ),
    table(
      headers: const ['الوضع', 'الرمز', 'العمود الذي يملؤه'],
      rows: const [
        ['حضور', '0', 'check_in_time'],
        ['انصراف', '1', 'check_out_time'],
        ['خروج استراحة', '2', 'break_out_time'],
        ['عودة من استراحة', '3', 'break_in_time'],
        ['بدء عمل إضافي', '4', 'overtime_in_time'],
        ['نهاية عمل إضافي', '5', 'overtime_out_time'],
      ],
      flex: const [1.4, 0.5, 1.6],
      latin: const [false, true, true],
    ),
    heading('المسار كاملًا'),
    bullets(const [
      'يفتح مصدر بيانات الجهاز مقبسًا على المنفذ 4370 ويقرأ سجل البصمات. '
          'الجهاز يعيد ذاكرته كاملة في كل قراءة، لا الجديد منها فقط.',
      'تُكتب كل بصمة في جدول device_punches تحت فهرس فريد على المعرّف والوقت، '
          'فتُهمَل البصمات التي سبق استيرادها دون خطأ.',
      'تُربط كل بصمة بموظف عبر device_user_id. البصمات التي لا يقابلها موظف '
          'تُحفظ ولا تُهمَل، وتظهر تحت مستخدمي الجهاز غير المربوطين.',
      'تُجمَّع بصمات الموظف الواحد في اليوم الواحد، وتُدمج البصمات المتكررة '
          'داخل نافذة ستين ثانية كي لا يبدو قارئ يتكرر ثلاث مرات كأنه ورديّة.',
      'إذا خلا اليوم من أي وضع محدَّد، وهو حال الجهاز حين لا يضغط أحد مفتاح '
          'الوضع، يُستخدم البديل: أبكر بصمة حضورًا وأحدثها انصرافًا. أي بصمة '
          'مكتوبة يدويًا في اليوم تُعطّل هذا البديل.',
      'يُقيَّم اليوم مقابل وردية الموظف وسماحاتها وتقويم العطلات وأيام الراحة '
          'وأذونات اليوم نفسه، ويُحسب التقييم بتاريخ البصمة لا بتاريخ اليوم، '
          'فيُقيَّم متأخرٌ سُحب بعد عطلة نهاية الأسبوع تقييمًا صحيحًا.',
      'يُكتب السجل اليومي أو يُوسَّع القائم. اليوم الذي يحمل corrected_at لا '
          'يُلمس، واليوم المُدخل يدويًا يُوسَّع ولا يُستبدل.',
    ]),
    callout(
      'الهوية: userId وليس uid',
      'يعرض الجهاز رقمين لكل شخص وهما غير متبادلين، وقد لا يكونان بالترتيب '
          'نفسه: uid هو رقم فتحة التسجيل، و userId هو ما تحمله سجلات البصمة. '
          'الاعتماد على الأول كان سيقيّد حضور كل شخص باسم شخص آخر. كذلك تُخزَّن '
          'الأسماء على الجهاز بترميز Windows-1256 لا UTF-8، فتصل مشوَّهة ما لم '
          'تُعَد قراءتها بالترميز الصحيح.',
      color: gold,
    ),

    pw.NewPage(),
    chapter(
      '10',
      'الوحدات الوظيفية',
      'أربع عشرة وحدة، ولكل منها مصدر البيانات الذي يملك استعلاماتها.',
    ),
    table(
      headers: const ['الوحدة', 'ما تقدّمه', 'الجداول التي تمسّها'],
      rows: const [
        ['auth', 'تسجيل الدخول والأدوار وإنشاء حساب المدير الأول', 'users'],
        [
          'dashboard',
          'لوحة اليوم: الحاضرون والمتأخرون والغائبون',
          'attendance_records · employees',
        ],
        [
          'attendance',
          'قائمة الحضور وتحريره وتصفيته',
          'attendance_records · employees',
        ],
        [
          'attendance_detail',
          'تفاصيل يوم واحد لموظف واحد مع استراحاته',
          'attendance_records',
        ],
        [
          'check_in',
          'التسجيل اليدوي للحضور والانصراف وتوليد التنبيهات',
          'attendance_records · admin_notifications',
        ],
        [
          'admin',
          'الموظفون والتقارير والتصدير إلى PDF و Excel',
          'employees · attendance_records · device_punches',
        ],
        [
          'device',
          'إعدادات الجهاز والمزامنة والمطابقات المعلّقة',
          'device_punches · pending_employee_matches · dismissed_device_users',
        ],
        ['shifts', 'إدارة الورديات وأيام الراحة', 'shifts · employees'],
        ['departments', 'إدارة قائمة الأقسام', 'departments · employees'],
        ['holidays', 'تقويم العطلات الرسمية', 'holidays'],
        [
          'permissions',
          'الأذونات والانتدابات والإجازات',
          'permission_requests',
        ],
        [
          'notifications',
          'عرض التنبيهات وتعليمها مقروءة',
          'admin_notifications',
        ],
        [
          'settings',
          'ساعات العمل الافتراضية وإعدادات التطبيق المحفوظة محليًا',
          'shifts',
        ],
        ['backup', 'نسخ ملف قاعدة البيانات نسخًا موثوقًا', 'guardsync.db'],
      ],
      flex: const [0.9, 2.1, 2.0],
      latin: const [true, false, true],
      fontSize: 7.8,
    ),

    pw.NewPage(),
    chapter(
      '11',
      'النسخ الاحتياطي والأمان والقيود المعروفة',
      'ما يحمي البيانات، وما يبقى خطرًا يجب أن يعرفه من يشغّل النظام.',
    ),
    heading('النسخ الاحتياطي'),
    para(
      'كل البيانات في ملف واحد على هذا الجهاز. عملية النسخ تُفرغ سجل الكتابة '
      'المسبقة في الملف الرئيسي أولًا عبر نقطة تفتيش كاملة، ثم تنسخه. بدون '
      'هذه الخطوة قد تكون النسخة ناقصة آخر ما كُتب.',
    ),
    bullets(const [
      'النسخة تُكتب بختم زمني في مجلد النسخ داخل مستندات المستخدم.',
      'لا يوجد خادم يحتفظ بنسخة ثانية. فقدان الجهاز دون نسخة احتياطية يعني '
          'فقدان التاريخ كاملًا.',
      'الجهاز يحتفظ بسجل بصماته الخاص، فيمكن إعادة بناء جزء من الحضور منه، '
          'لكن الموظفين والأذونات والملاحظات موجودة هنا فقط.',
    ]),
    heading('الأمان'),
    bullets(const [
      'كلمات المرور تُخزَّن مجزّأة بملح عشوائي لكل حساب، ولا تُحفظ كلمة المرور '
          'نصًا في أي موضع.',
      'يُنشأ حساب مدير واحد عند أول تشغيل إذا كان جدول الحسابات فارغًا، ولا '
          'يُعاد إنشاؤه بعدها. يجب تغيير بياناته قبل أي تشغيل فعلي، ويمكن '
          'تعيينها وقت البناء عبر متغيّرات التعريف.',
      'الاتصال بالجهاز داخل الشبكة المحلية فقط، ولا يخرج أي شيء إلى الإنترنت.',
      'ملف قاعدة البيانات غير مشفَّر. من يملك وصولاً إلى نظام الملفات على هذا '
          'الجهاز يملك البيانات.',
    ], dot: plum),
    heading('قيود يجب أخذها في الحسبان'),
    bullets(const [
      'ساعة الجهاز هي مصدر أوقات البصمات. انحرافها يقيّد الحضور في وقت خاطئ، '
          'وبعد منتصف الليل في يوم خاطئ. يُنبَّه المدير إذا تجاوز الانحراف '
          'دقيقتين.',
      'القسم والوردية روابط منطقية لا قيود مرجعية، فسلامتهما مسؤولية مصادر '
          'البيانات لا المخطط.',
      'التصحيح مسموح مرة واحدة في اليوم نفسه، وبعدها يصبح السجل مقفلًا أمام '
          'الطيّ الآلي.',
      'العطلة خاصية للتاريخ وتسري على الجميع، بينما يوم الراحة خاصية للوردية '
          'ويسري على من عليها فقط. الخلط بينهما يعطي تقييمًا خاطئًا.',
    ], dot: gold),

    pw.NewPage(),
    chapter(
      '12',
      'ملحق: القيم المعتمدة',
      'القيم النصية التي يفهمها التطبيق في أعمدة الحالة والنوع.',
    ),
    heading('attendance_records.status'),
    table(
      headers: const ['القيمة', 'المعنى'],
      rows: const [
        ['pending', 'القيمة الابتدائية قبل تقييم اليوم.'],
        ['present', 'حاضر ضمن السماح المقرَّر لورديّته.'],
        ['late', 'تجاوز الحضور سماح التأخير في وردية الموظف.'],
        ['early_leave', 'انصرف قبل نهاية الدوام بأكثر من السماح.'],
        ['travel_permission', 'غيابه مغطّى بانتداب.'],
        ['absent', 'لا بصمة ولا إذن في يوم عمل.'],
      ],
      flex: const [1.0, 3.2],
      latin: const [true, false],
    ),
    heading('attendance_records.source'),
    table(
      headers: const ['القيمة', 'المعنى'],
      rows: const [
        ['manual', 'أُدخل من شاشات التطبيق. لا تستبدله المزامنة بل توسّعه.'],
        ['device', 'نتج عن طيّ بصمات الجهاز.'],
      ],
      flex: const [1.0, 3.2],
      latin: const [true, false],
    ),
    heading('permission_requests.permission_type'),
    table(
      headers: const ['القيمة', 'المعنى'],
      rows: const [
        ['travel_permission', 'انتداب أو مهمة خارج مقر العمل.'],
        ['vacation', 'إجازة.'],
        ['other', 'أي إذن آخر يوضّحه حقل السبب.'],
      ],
      flex: const [1.0, 3.2],
      latin: const [true, false],
    ),
    heading('users.role'),
    table(
      headers: const ['القيمة', 'المعنى'],
      rows: const [
        ['admin', 'صلاحية كاملة: الموظفون والإعدادات والجهاز والتقارير.'],
        ['guard', 'القيمة الافتراضية. تسجيل الحضور والاطلاع فقط.'],
      ],
      flex: const [1.0, 3.2],
      latin: const [true, false],
    ),
    heading('admin_notifications.type'),
    table(
      headers: const ['القيمة', 'المعنى'],
      rows: const [
        [
          'early_leave_threshold',
          'تجاوز الموظف عدد مرات الانصراف المبكر المسموح بها في الفترة.',
        ],
      ],
      flex: const [1.0, 3.2],
      latin: const [true, false],
    ),
    gap(16),
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: navy,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ar(
            'مصدر هذه الوثيقة',
            size: 9.6,
            bold: true,
            color: white,
            spacing: 0,
          ),
          gap(5),
          ar(
            'كل ما ورد هنا مستخرج من مخطط قاعدة البيانات الفعلي في الملف '
            'lib/core/database/app_database.dart ومن مصادر بيانات الوحدات. '
            'عند أي تعديل على المخطط تُعاد هذه الوثيقة بتشغيل الأمر '
            'dart run tool/generate_erd_pdf.dart من جذر المشروع.',
            size: 8.6,
            color: PdfColors.blueGrey100,
            align: pw.TextAlign.justify,
          ),
        ],
      ),
    ),
  ],
);
