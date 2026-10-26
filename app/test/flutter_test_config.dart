import 'dart:async';

import 'package:app/help_check.dart';

/// Every test file: "Did you need help?" (board 8) stays off unless a test turns it on, so
/// the sheet doesn't cover each finished page (test/help_check_test.dart tests it).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  helpCheckEnabled = false;
  await testMain();
}
