import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../api.dart';
import '../platform.dart';
import 'page_letters.dart';

/// Offline basic reading (board 5e; CLAUDE.md: "offline fallback with ML Kit OCR +
/// device TTS"). When the server can't be reached, fails or is slow, the photo is read
/// on this phone by ML Kit's on-device Latin text recognition, bundled in the app:
/// nothing leaves the phone. Basic reading only: no tables, columns, headings, letter
/// check or Explain. Number safety stays (CLAUDE.md rule 2):
/// - a number below [numberThreshold] confidence, or with no confidence, is "unclear";
/// - every number is read a second time from a crop around it and its neighbours,
///   and a number whose two readings differ is "unclear";
/// - a money page whose amounts aren't all reliable keeps only what passed every
///   check, as the server does (safety.money_photo_check).

/// One recognised word on the upright photo, in pixels.
class SeenWord {
  const SeenWord(
    this.text,
    this.confidence,
    this.left,
    this.top,
    this.width,
    this.height,
  );
  final String text;
  final double? confidence; // null where the platform gives none (then never trusted for numbers)
  final int left, top, width, height;
}

class SeenLine {
  const SeenLine(this.words);
  final List<SeenWord> words;
  int get top => words.map((w) => w.top).reduce((a, b) => a < b ? a : b);
  int get left => words.map((w) => w.left).reduce((a, b) => a < b ? a : b);
  int get bottom =>
      words.map((w) => w.top + w.height).reduce((a, b) => a > b ? a : b);
  int get right =>
      words.map((w) => w.left + w.width).reduce((a, b) => a > b ? a : b);
}

/// A photo opened for reading on the phone.
abstract class OfflinePhoto {
  int get width;
  int get height;
  Future<List<SeenLine>> read();

  /// The lines in a crop of the photo, scaled by [scale]; null if crops can't be read here.
  Future<List<SeenLine>?> readCrop(
    int left,
    int top,
    int width,
    int height,
    double scale,
  );

  /// A flattened copy for faint print (the paper evened out, then full contrast), or null if
  /// this phone can't make one. Its reading replaces this one only if it finds more words.
  Future<OfflinePhoto?> flattened();

  /// Deletes every file made for this photo.
  Future<void> close();
}

/// Opens photos for on-device reading; null where this platform can't (the web).
abstract class PageRecognizer {
  Future<OfflinePhoto?> open(Uint8List bytes);
}

/// ML Kit on Android and iOS: the photo is turned upright and kept in the app's private
/// cache only while it is read (android/.../OfflineChannels.kt, ios/Runner/MaganaChannels.swift).
class MlKitRecognizer implements PageRecognizer {
  static const _channel = MethodChannel('magana/offline');

  @override
  Future<OfflinePhoto?> open(Uint8List bytes) async {
    if (runningOnWeb) return null;
    final Map<Object?, Object?>? upright;
    try {
      upright = await _channel.invokeMapMethod('upright', {'bytes': bytes});
    } on MissingPluginException {
      return null; // no crop and upright helper on this platform: don't read offline
    }
    if (upright == null) return null;
    return _MlKitPhoto(
      upright['path']! as String,
      upright['width']! as int,
      upright['height']! as int,
    );
  }
}

class _MlKitPhoto implements OfflinePhoto {
  _MlKitPhoto(this.path, this.width, this.height);
  final String path;
  @override
  final int width;
  @override
  final int height;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _files = <String>[];

  static List<SeenLine> _lines(RecognizedText text) => [
    for (final block in text.blocks)
      for (final line in block.lines)
        if (line.elements.isNotEmpty)
          SeenLine([
            for (final e in line.elements)
              SeenWord(
                e.text,
                e.confidence,
                e.boundingBox.left.round(),
                e.boundingBox.top.round(),
                e.boundingBox.width.round(),
                e.boundingBox.height.round(),
              ),
          ]),
  ];

  @override
  Future<List<SeenLine>> read() async =>
      _lines(await _recognizer.processImage(InputImage.fromFilePath(path)));

  @override
  Future<List<SeenLine>?> readCrop(
    int left,
    int top,
    int width,
    int height,
    double scale,
  ) async {
    final crop = await MlKitRecognizer._channel.invokeMethod<String>('crop', {
      'path': path,
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'scale': scale,
    });
    if (crop == null) return null;
    _files.add(crop);
    try {
      return _lines(
        await _recognizer.processImage(InputImage.fromFilePath(crop)),
      );
    } finally {
      await MlKitRecognizer._channel.invokeMethod('delete', {'path': crop});
      _files.remove(crop);
    }
  }

  @override
  Future<OfflinePhoto?> flattened() async {
    final flat = await MlKitRecognizer._channel
        .invokeMapMethod<String, Object?>('flatten', {'path': path});
    if (flat == null) return null;
    return _MlKitPhoto(
      flat['path']! as String,
      flat['width']! as int,
      flat['height']! as int,
    );
  }

  @override
  Future<void> close() async {
    await _recognizer.close();
    for (final f in [path, ..._files]) {
      await MlKitRecognizer._channel.invokeMethod('delete', {'path': f});
    }
  }
}

/// The recognizer the app uses; tests replace it.
PageRecognizer pageRecognizer = MlKitRecognizer();

const numberThreshold = 0.90; // as the server: pending clinical sign-off
const lineThreshold = 0.75;
const rereadHeight =
    36.0; // crops are scaled so text is about this tall (as the server)
const cutMargin = 0.004; // a word this close to the photo's edge runs off it

final _digit = RegExp(r'\d');
final _amount = RegExp(
  r'(?<![\d/.:-])[₦N#]?\d{1,3}(?:,\d{3})+(?:\.\d{2})?(?![\d/:])|(?<![\d/.:-])[₦N#]?\d+\.\d{2}(?![\d/:])',
);
final _date = RegExp(
  r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}[-/ ]?(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-/ ,]*\d{2,4}\b',
  caseSensitive: false,
);

String _digitsOf(String w) => w.replaceAll(RegExp(r'[^\d]'), '');

/// Reads [bytes] on this phone into the same shape as the server's /read, or null
/// where this phone can't read offline.
Future<ReadResult?> readOnPhone(
  Uint8List bytes, {
  required String mode,
  PageRecognizer? recognizer,
}) async {
  final opened = await (recognizer ?? pageRecognizer).open(bytes);
  if (opened == null) return null;
  var photo = opened;
  try {
    var seen = await photo.read();
    // Thermal or faint print (as the server): a reading that is nearly empty or unsure is
    // tried again on a flattened copy, kept only if it finds more words. Every later step,
    // each number's second reading included, then uses that copy.
    var enhanced = false;
    if (offlineFlatten && readsFaint(seen)) {
      final flat = await photo.flattened();
      if (flat != null) {
        final again = await flat.read();
        if (_wordCount(again) > _wordCount(seen)) {
          await photo.close();
          (photo, seen, enhanced) = (flat, again, true);
        } else {
          await flat.close();
        }
      }
    }
    return ReadResult.fromJson(
      await _reading(photo, mode, seen, enhanced: enhanced),
    );
  } finally {
    await photo.close();
  }
}

/// Faint-print retry on the phone: on unless a measurement turns it off.
bool offlineFlatten = true;

int _wordCount(List<SeenLine> lines) =>
    [for (final l in lines) ...l.words]
        .where((w) => w.text.trim().length >= 2)
        .length;

/// Nearly empty (under 5 words) or unsure (mean confidence under 0.75, when the phone gives
/// confidence: ML Kit on iOS doesn't), as the server's reader.reads_faint.
bool readsFaint(List<SeenLine> lines) {
  final words = [for (final l in lines) ...l.words]
      .where((w) => w.text.trim().length >= 2)
      .toList();
  if (words.length < 5) return true;
  final confs = [for (final w in words) ?w.confidence];
  if (confs.isEmpty) return false;
  return confs.reduce((a, b) => a + b) / confs.length < 0.75;
}

Future<Map<String, dynamic>> _reading(
  OfflinePhoto photo,
  String mode,
  List<SeenLine> read, {
  bool enhanced = false,
}) async {
  final seen = [...read]..sort((a, b) => a.top.compareTo(b.top));
  final lines = <Map<String, dynamic>>[];
  final warnings = <Map<String, dynamic>>[];
  // A Hausa, Yorùbá or Igbo page (as the server finds it): one warning for the page, and
  // a digit inside a word is an unclear letter, never a number (page_letters.dart).
  final language = pageLanguageOf(
    [for (final l in seen) ...l.words.map((w) => w.text)].join(' '),
  );
  final letterMarks = <Map<String, dynamic>>[];
  // ML Kit on iOS gives no confidence at all. Then every number is "unclear number" (below);
  // the lines get one page warning instead of a warning on every line.
  final sure = seen.any((l) => l.words.any((w) => w.confidence != null));
  for (final (i, line) in seen.indexed) {
    final confs = [for (final w in line.words) w.confidence ?? 0.0];
    final conf = confs.reduce((a, b) => a + b) / confs.length;
    lines.add({
      'text': line.words.map((w) => w.text).join(' '),
      'confidence': conf,
      'top': line.top,
      'left': line.left,
      'width': line.right - line.left,
      'height': line.bottom - line.top,
      'words': [
        for (final w in line.words)
          {
            'text': w.text,
            'confidence': w.confidence,
            'left': w.left,
            'top': w.top,
            'width': w.width,
            'height': w.height,
          },
      ],
    });
    var numberFlagged = false;
    for (final (j, w) in line.words.indexed) {
      if (!_digit.hasMatch(w.text)) continue;
      if (language != null && digitInWord(w.text)) {
        letterMarks.add({
          'block_index': i,
          'word_index': j,
          'kind': 'unclear_letter',
        });
        continue;
      }
      final code = await _numberCheck(photo, line, j);
      if (code != null) {
        warnings.add({'block_index': i, 'word_index': j, 'code': code});
        numberFlagged = true;
      }
    }
    if (!numberFlagged && sure && conf < lineThreshold) {
      warnings.add({'block_index': i, 'code': 'low_confidence'});
    }
  }
  final out = <String, dynamic>{
    'offline': true,
    'columns': 1,
    'tips': [
      if (!sure && seen.isNotEmpty) 'offline_no_confidence',
      if (enhanced) 'faint_print',
      ..._cutOff(photo, seen),
      if (language != null) 'letters_$language',
    ],
    'page_language': language,
    'letter_marks': letterMarks,
    'lines': lines,
    'tables': const [],
    'faint_regions': const [],
    'warnings': warnings,
    'cell_warnings': const [],
  };
  return mode == 'money' ? _moneyCheck(out) : out;
}

/// null when the number is read reliably; otherwise its warning code.
Future<String?> _numberCheck(OfflinePhoto photo, SeenLine line, int j) async {
  final w = line.words[j];
  if ((w.confidence ?? 0) < numberThreshold) return 'low_confidence_number';
  // A second reading from a crop around the number and its neighbours (as the server's
  // reader.reread_numbers): whole words, not slivers.
  final from = j > 0 ? j - 1 : 0;
  final to = j < line.words.length - 1 ? j + 1 : j;
  final window = line.words.sublist(from, to + 1);
  final h = window.map((x) => x.height).reduce((a, b) => a > b ? a : b);
  final padX = (h * 0.25).round(), padY = (h * 0.3).round();
  final left = window.map((x) => x.left).reduce((a, b) => a < b ? a : b) - padX;
  final top = window.map((x) => x.top).reduce((a, b) => a < b ? a : b) - padY;
  final right =
      window.map((x) => x.left + x.width).reduce((a, b) => a > b ? a : b) +
      padX;
  final bottom =
      window.map((x) => x.top + x.height).reduce((a, b) => a > b ? a : b) +
      padY;
  final scale = h > 0 && h < rereadHeight ? rereadHeight / h : 1.0;
  final crop = await photo.readCrop(
    left < 0 ? 0 : left,
    top < 0 ? 0 : top,
    right - (left < 0 ? 0 : left),
    bottom - (top < 0 ? 0 : top),
    scale,
  );
  if (crop == null) {
    return 'low_confidence_number'; // no second reading: never trusted
  }
  final words = [for (final l in crop) ...l.words];
  final SeenWord? again = words.length == window.length
      ? words[j - from]
      : switch (words.where((x) => _digit.hasMatch(x.text)).toList()) {
          [final only] => only,
          _ => null,
        };
  if (again == null || _digitsOf(again.text) != _digitsOf(w.text)) {
    return 'number_mismatch';
  }
  return null;
}

/// Words touching the photo's edge: part of the page is outside it (as reader.cut_off).
List<String> _cutOff(OfflinePhoto photo, List<SeenLine> lines) {
  final mx = (photo.width * cutMargin).ceil().clamp(3, 1 << 20);
  final my = (photo.height * cutMargin).ceil().clamp(3, 1 << 20);
  final sides = <String>{};
  for (final w in [for (final l in lines) ...l.words]) {
    if (w.text.trim().length < 2 || w.width == 0) continue;
    if (w.top <= my) sides.add('top');
    if (w.top + w.height >= photo.height - my) sides.add('bottom');
    if (w.left <= mx) sides.add('left');
    if (w.left + w.width >= photo.width - mx) sides.add('right');
  }
  return [
    for (final s in ['top', 'bottom', 'left', 'right'])
      if (sides.contains(s)) 'cut_off_$s',
  ];
}

/// A money page whose amounts aren't all reliable is not read in part (the server's
/// safety.money_photo_check): any warning, or a dated row with fewer amounts than the
/// page's other dated rows, and only what passed every check is kept.
Map<String, dynamic> _moneyCheck(Map<String, dynamic> result) {
  final lines = (result['lines'] as List).cast<Map<String, dynamic>>();
  final flagged = {
    for (final w in (result['warnings'] as List).cast<Map<String, dynamic>>())
      w['block_index'] as int,
  };
  final rows = <List<int>>[];
  final order = [
    for (var i = 0; i < lines.length; i++) i,
  ]..sort((a, b) => (lines[a]['top'] as int).compareTo(lines[b]['top'] as int));
  for (final i in order) {
    final h = (lines[i]['height'] as int).clamp(1, 1 << 20);
    final mid = (lines[i]['top'] as int) + h / 2;
    if (rows.isNotEmpty) {
      final last = lines[rows.last.first];
      final lh = (last['height'] as int).clamp(1, 1 << 20);
      final lastMid = (last['top'] as int) + lh / 2;
      if ((mid - lastMid).abs() <= (h > lh ? h : lh) / 2) {
        rows.last.add(i);
        continue;
      }
    }
    rows.add([i]);
  }
  String text(List<int> row) =>
      ([...row]..sort(
            (a, b) =>
                (lines[a]['left'] as int).compareTo(lines[b]['left'] as int),
          ))
          .map((i) => lines[i]['text'] as String)
          .join(' ');
  final dated = [
    for (final r in rows)
      if (_date.hasMatch(text(r))) r,
  ];
  final counts = [for (final r in dated) _amount.allMatches(text(r)).length];
  final usual = counts.isEmpty
      ? 0
      : counts.reduce(
          (a, b) =>
              counts.where((c) => c == a).length >=
                  counts.where((c) => c == b).length
              ? a
              : b,
        );
  final short = <int>{
    for (final (k, r) in dated.indexed)
      if (counts[k] == 0 || counts[k] < usual) ...r,
  };
  if (flagged.isEmpty && short.isEmpty) return result;
  final keep = [
    for (final (i, l) in lines.indexed)
      if (!flagged.contains(i) && !short.contains(i)) l,
  ];
  return {
    ...result,
    'lines': keep,
    'warnings': const [],
    'tips': [
      'money_amounts_unreliable',
      'reading_incomplete',
      ...(result['tips'] as List),
    ],
    'incomplete': true,
  };
}

/// Why a page was read on the phone: no connection, or the server failed or was slow.
enum OfflineReason { noInternet, slow }
