// Offline reading (ML Kit on this phone) on private test photos, before and after the faint-print
// retry. Counts only: no text is printed, and the photos are deleted when done.
//   flutter run -t tool/measure_offline.dart -d <emulator>
// then copy JPGs into the app's files folder (adb push + run-as cp; docs/FINDINGS.md, 27 Oct).
import 'dart:io';

import 'package:app/offline/offline_reader.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/measure');
  await dir.create(recursive: true);
  debugPrint('MEASURE waiting for photos in ${dir.path}');
  var files = <File>[];
  for (var i = 0; i < 300 && files.isEmpty; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (File('${dir.path}/ready').existsSync()) {
      files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    }
  }
  for (final f in files) {
    final bytes = await f.readAsBytes();
    for (final on in [false, true]) {
      offlineFlatten = on;
      final watch = Stopwatch()..start();
      final r = await readOnPhone(bytes, mode: 'school');
      final ms = watch.elapsedMilliseconds;
      if (r == null) {
        debugPrint('MEASURE ${f.uri.pathSegments.last} flatten=$on: cannot read offline');
        continue;
      }
      final lines = r.items.where((i) => !i.isFaint).toList();
      final words = lines.fold<int>(0, (n, i) => n + i.words.where((w) => w.trim().isNotEmpty).length);
      final codes = <String, int>{};
      for (final i in lines) {
        for (final c in i.codes) {
          codes[c] = (codes[c] ?? 0) + 1;
        }
      }
      debugPrint('MEASURE ${f.uri.pathSegments.last} flatten=$on: words $words, lines ${lines.length}, '
          'warnings ${codes.values.fold(0, (a, b) => a + b)} $codes, tips ${r.tips}, $ms ms');
    }
    await f.delete();
  }
  await dir.delete(recursive: true);
  debugPrint('MEASURE done');
}
