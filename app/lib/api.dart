import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'platform.dart';

/// Backend address. Override with --dart-define=MAGANA_API=http://host:8000.
const _configured = String.fromEnvironment('MAGANA_API');

String get apiBase => _configured.isNotEmpty ? _configured : defaultApiBase;

enum ItemKind { line, row }

/// One thing the Reader speaks: a line of text, or one row of a table.
/// Wording (labels, warnings) is added by the Reader in the app language.
class ReadItem {
  ReadItem({
    required this.kind,
    required this.number,
    required this.total,
    required this.text,
    required this.top,
    this.table,
    this.cells = const [],
    this.unsure = false,
  });

  final ItemKind kind;
  final int number; // 1-based line number, or row number within the table body
  final int total; // lines on the page, or body rows in the table
  final int? table; // 1-based table number when the page has more than one
  final String
  text; // exactly as printed: numbers, doses, amounts never rewritten
  final int top; // vertical position on the page, for reading order
  final List<(String header, String value)> cells; // a table row's cells
  final bool unsure; // the backend flagged low confidence

  bool get isRow => kind == ItemKind.row;
}

class ReadResult {
  ReadResult({required this.tips, required this.items});

  final List<String>
  tips; // capture guidance from the backend: too dark, blurry
  final List<ReadItem> items;

  int get unsureCount => items.where((i) => i.unsure).length;

  /// Parses the backend /read response. Which lines and cells are uncertain is
  /// decided by the backend (`warnings`, `cell_warnings`), never guessed here.
  factory ReadResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(Object? v) =>
        (v as List? ?? const []).cast<Map<String, dynamic>>();

    final lines = list(json['lines']);
    final unsureLines = {
      for (final w in list(json['warnings'])) w['block_index'],
    };
    final items = <ReadItem>[
      for (var i = 0; i < lines.length; i++)
        ReadItem(
          kind: ItemKind.line,
          number: i + 1,
          total: lines.length,
          text: lines[i]['text'] as String? ?? '',
          top: (lines[i]['top'] as num?)?.toInt() ?? 0,
          unsure: unsureLines.contains(i),
        ),
    ];

    final tables = list(json['tables']);
    // (table index, row index on the page) of every uncertain cell.
    final unsureCells = {
      for (final w in list(json['cell_warnings'])) (w['table_index'], w['row']),
    };
    for (var t = 0; t < tables.length; t++) {
      final rows = [
        for (final r in (tables[t]['rows'] as List? ?? const [])) list(r),
      ];
      final hasHeader = tables[t]['header'] == true && rows.length > 1;
      final header = hasHeader
          ? [for (final c in rows.first) c['text'] as String? ?? '']
          : const <String>[];
      final first = hasHeader ? 1 : 0;
      final top = (tables[t]['top'] as num?)?.toInt() ?? 0;
      for (var r = first; r < rows.length; r++) {
        final cells = rows[r];
        items.add(
          ReadItem(
            kind: ItemKind.row,
            number: r - first + 1,
            total: rows.length - first,
            table: tables.length > 1 ? t + 1 : null,
            text: cells.map((c) => c['text'] ?? '').join(' · '),
            top:
                top +
                r, // keeps rows in order and after anything above the table
            cells: [
              for (final c in cells)
                (
                  switch (c['col']) {
                    final int col when col < header.length => header[col],
                    _ => '',
                  },
                  c['text'] as String? ?? '',
                ),
            ],
            unsure: unsureCells.contains((t, r)),
          ),
        );
      }
    }
    // Dart's sort is not stable, so break ties by original position.
    final indexed = items.indexed.toList()
      ..sort(
        (a, b) => a.$2.top != b.$2.top
            ? a.$2.top.compareTo(b.$2.top)
            : a.$1.compareTo(b.$1),
      );
    return ReadResult(
      tips: (json['tips'] as List? ?? const []).cast<String>(),
      items: [for (final e in indexed) e.$2],
    );
  }
}

enum ApiError { unreachable, failed }

class ApiException implements Exception {
  ApiException(this.error, [this.detail = '']);
  final ApiError error;
  final String detail; // backend message, if any (English)
  @override
  String toString() => '$error $detail';
}

class MaganaApi {
  MaganaApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Sends the photo to /read. The photo is only held in memory for the request.
  Future<ReadResult> read(
    Uint8List bytes, {
    String filename = 'page.jpg',
    String mode = 'school',
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/read'))
      ..fields['mode'] = mode
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException(ApiError.unreachable);
    }
    if (res.statusCode != 200) {
      String detail = '';
      try {
        detail = (jsonDecode(res.body) as Map)['detail']?.toString() ?? '';
      } catch (_) {}
      throw ApiException(ApiError.failed, detail);
    }
    return ReadResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
