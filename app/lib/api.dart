import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'platform.dart';

/// Backend address. Override with --dart-define=MAGANA_API=http://host:8000.
const _configured = String.fromEnvironment('MAGANA_API');

String get apiBase => _configured.isNotEmpty ? _configured : defaultApiBase;

enum ItemKind { line, row, faint }

/// Number warnings: the flagged word is never spoken as if it were certain.
const numberCodes = {
  'unreadable_number',
  'low_confidence_number',
  'number_mismatch',
};

/// One thing the Reader speaks: a line of text, one row of a table, or a band
/// of faint print the backend could not read. Wording comes from the Reader in
/// the app language; this holds only what the backend returned.
class ReadItem {
  ReadItem({
    required this.kind,
    required this.top,
    this.number = 0,
    this.total = 0,
    this.table,
    this.words = const [],
    this.unclearWords = const {},
    this.cells = const [],
    this.codes = const [],
    this.where = '',
  });

  final ItemKind kind;
  final int top; // vertical position on the page, for reading order
  final int number; // 1-based line number, or row number within the table body
  final int total; // lines on the page, or body rows in the table
  final int? table; // 1-based table number when the page has more than one
  final List<String> words; // a line's words, exactly as printed
  final Set<int> unclearWords; // indices of words holding an unreliable number
  final List<Cell> cells; // a table row's cells
  final List<String> codes; // backend warning codes for this item
  final String where; // faint region: top | middle | bottom

  bool get isRow => kind == ItemKind.row;
  bool get isFaint => kind == ItemKind.faint;
  bool get unsure => codes.isNotEmpty;
  String get text => words.join(' ');

  /// The code to say: number problems first, they matter most.
  String? get code => codes.isEmpty
      ? null
      : codes.firstWhere(numberCodes.contains, orElse: () => codes.first);
}

class Cell {
  const Cell(this.header, this.value, {this.unclear = false});
  final String header;
  final String value; // exactly as printed
  final bool
  unclear; // holds an unreliable number: say "unclear number" instead
}

class ReadResult {
  ReadResult({required this.tips, required this.items, this.json});

  final List<String> tips; // capture tip codes: too_dark, blurry
  final List<ReadItem> items;

  /// The backend's text-only response, kept so a reading can be saved to the
  /// library and reopened. Photos are never part of it.
  final Map<String, dynamic>? json;

  int get unsureCount => items.where((i) => i.unsure).length;
  int get readableCount => items.where((i) => !i.isFaint).length;

  /// Parses the backend /read response. Which lines, words and cells are
  /// uncertain is decided by the backend, never guessed here.
  factory ReadResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(Object? v) =>
        (v as List? ?? const []).cast<Map<String, dynamic>>();

    final lineCodes = <int, List<String>>{};
    final unclear = <int, Set<int>>{};
    for (final w in list(json['warnings'])) {
      final i = w['block_index'] as int;
      final code = w['code'] as String? ?? 'low_confidence';
      lineCodes.putIfAbsent(i, () => []).add(code);
      if (numberCodes.contains(code) && w['word_index'] is int) {
        unclear.putIfAbsent(i, () => {}).add(w['word_index'] as int);
      }
    }

    final lines = list(json['lines']);
    final items = <ReadItem>[];
    for (var i = 0; i < lines.length; i++) {
      final words = [
        for (final w in list(lines[i]['words'])) w['text'] as String? ?? '',
      ];
      items.add(
        ReadItem(
          kind: ItemKind.line,
          number: i + 1,
          total: lines.length,
          top: (lines[i]['top'] as num?)?.toInt() ?? 0,
          words: words.isNotEmpty
              ? words
              : (lines[i]['text'] as String? ?? '').split(' '),
          unclearWords: unclear[i] ?? const {},
          codes: lineCodes[i] ?? const [],
        ),
      );
    }

    final cellCodes = <(int, int, int), List<String>>{};
    for (final w in list(json['cell_warnings'])) {
      cellCodes
          .putIfAbsent((
            w['table_index'] as int,
            w['row'] as int,
            w['col'] as int,
          ), () => [])
          .add(w['code'] as String? ?? 'low_confidence');
    }
    final tables = list(json['tables']);
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
        final codes = <String>[];
        final cells = <Cell>[];
        for (final c in rows[r]) {
          final col = c['col'] as int? ?? 0;
          final found = cellCodes[(t, c['row'] as int? ?? r, col)] ?? const [];
          codes.addAll(found);
          cells.add(
            Cell(
              col < header.length ? header[col] : '',
              c['text'] as String? ?? '',
              unclear: found.any(numberCodes.contains),
            ),
          );
        }
        items.add(
          ReadItem(
            kind: ItemKind.row,
            number: r - first + 1,
            total: rows.length - first,
            table: tables.length > 1 ? t + 1 : null,
            top:
                top +
                r, // keeps rows in order and after anything above the table
            cells: cells,
            codes: codes,
          ),
        );
      }
    }

    for (final f in list(json['faint_regions'])) {
      items.add(
        ReadItem(
          kind: ItemKind.faint,
          top: (f['top'] as num?)?.toInt() ?? 0,
          codes: [f['code'] as String? ?? 'faint_region'],
          where: f['where'] as String? ?? '',
        ),
      );
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
      json: json,
    );
  }
}

class TriageQuestion {
  const TriageQuestion({
    required this.id,
    required this.type,
    required this.message,
    this.text,
    this.askIf,
  });

  final String id;
  final String type; // yes_no | number
  final String? text; // Ibà's wording in the app language, when Ibà answered
  final String message; // fallback message code (q_<id>), worded by the app
  final String? askIf; // only asked when this question was answered yes
}

class ApiException implements Exception {
  ApiException(this.code);

  /// A backend message code (`unknown_mode`, `not_allowed_for_tier`, ...) or
  /// `unreachable` / `failed` from the app itself.
  final String code;
  @override
  String toString() => 'ApiException($code)';
}

class MaganaApi {
  MaganaApi({http.Client? client, Map<String, String> Function()? headers})
    : _client = client ?? http.Client(),
      _headers = headers ?? (() => const {});
  final http.Client _client;

  /// Age tier and consent headers, sent with every request (see ProfileController).
  final Map<String, String> Function() _headers;

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Object? body,
  }) async {
    final req = http.Request(method, Uri.parse('$apiBase$path'))
      ..headers.addAll(_headers());
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('unreachable');
    }
    final decoded = () {
      try {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        return null;
      }
    }();
    if (res.statusCode != 200) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(
        detail is Map && detail['code'] is String
            ? detail['code'] as String
            : 'failed',
      );
    }
    return decoded is Map<String, dynamic>
        ? decoded
        : throw ApiException('failed');
  }

  /// Ibà quick-check questions in [lang], and whether they came from Ibà or from
  /// Magana's built-in fallback set.
  Future<({List<TriageQuestion> questions, bool fromIba})> triageQuestions(
    String lang,
  ) async {
    final body = await _json('GET', '/triage/questions?lang=$lang');
    return (
      fromIba: body['source'] == 'iba',
      questions: [
        for (final q
            in (body['questions'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          TriageQuestion(
            id: q['id'] as String,
            type: q['type'] as String? ?? 'yes_no',
            text: q['text'] as String?,
            message: q['message'] as String? ?? 'q_${q['id']}',
            askIf: q['ask_if'] as String?,
          ),
      ],
    );
  }

  /// Priority and message code for the answers (danger signs are always an emergency).
  Future<({String priority, String message})> triageAssess(
    Map<String, Object> answers,
  ) async {
    final body = await _json('POST', '/triage/assess', body: answers);
    return (
      priority: body['priority'] as String,
      message: body['message'] as String,
    );
  }

  /// Asks the nurse desk for a call back; returns a message code.
  Future<String> requestCallback({
    required String reason,
    required String language,
    String? priority,
  }) async {
    final body = await _json(
      'POST',
      '/callback',
      body: {'reason': reason, 'language': language, 'priority': ?priority},
    );
    return body['code'] as String? ?? 'callback_booked';
  }

  /// Sends the photo to /read. The photo is only held in memory for the request.
  Future<ReadResult> read(
    Uint8List bytes, {
    String filename = 'page.jpg',
    String mode = 'school',
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/read'))
      ..headers.addAll(_headers())
      ..fields['mode'] = mode
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException('unreachable');
    }
    if (res.statusCode != 200) {
      String code = 'failed';
      try {
        final detail = (jsonDecode(res.body) as Map)['detail'];
        if (detail is Map && detail['code'] is String) {
          code = detail['code'] as String;
        }
      } catch (_) {}
      throw ApiException(code);
    }
    return ReadResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
