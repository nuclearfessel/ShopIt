// Minimal CSV (RFC 4180): fields containing a comma, quote, line break or
// leading/trailing space are quoted, and quotes inside are doubled.

String _quote(String field) {
  final needs =
      field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r') ||
      field != field.trim();
  return needs ? '"${field.replaceAll('"', '""')}"' : field;
}

/// Turns rows of fields into CSV text (CRLF line endings, as Excel expects).
String encodeCsv(List<List<String>> rows) =>
    rows.map((r) => r.map(_quote).join(',')).join('\r\n');

/// Reads CSV text into rows of fields.
///
/// Accepts LF, CRLF or CR line endings, a leading byte-order mark, quoted
/// fields with commas and line breaks inside, and a missing final newline.
/// Completely empty lines are skipped.
List<List<String>> decodeCsv(String text) {
  var s = text;
  if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) s = s.substring(1);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldStarted = false; // distinguishes "" (empty field) from nothing

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    // A line with a single empty field is a blank line.
    if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
      continue;
    }
    switch (c) {
      case '"':
        // A quote opens a quoted field only at the start of a field.
        if (!fieldStarted && field.isEmpty) {
          inQuotes = true;
          fieldStarted = true;
        } else {
          field.write(c);
        }
      case ',':
        endField();
      case '\r':
        if (i + 1 < s.length && s[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        field.write(c);
        fieldStarted = true;
    }
  }
  if (fieldStarted || field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
