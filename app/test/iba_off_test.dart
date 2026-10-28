// Ibà, the AI health assistant, isn't running in the test phase (no GPU; Nurse Balogun's review,
// build 7). "Talk to a health worker" works without it: the call back, Magana's own danger-sign
// questions and the clinic / 112 advice. Nothing reachable says Ibà (lib/features.dart).
import 'package:app/features.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'health_worker_test.dart' show open, tap;

final en = lookupAppLocalizations(const Locale('en'));

void main() {
  test('Ibà is off in this build', () => expect(ibaAssistant, isFalse));

  testWidgets('every tap on Talk to a health worker: no Ibà, no dead end', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Ibà'), findsNothing);
    expect(find.text(en.aiAssistantSoon), findsOneWidget);
    // The danger-sign questions open and are answered with Magana's own rules.
    await tap(tester, en.dangerCheckFirst);
    expect(find.textContaining('Ibà'), findsNothing);
    expect(find.text(en.quickCheckNoteRules), findsOneWidget);
    expect(find.text(en.quickCheckProgressFallback(1, 2)), findsOneWidget);
    // Back to the call-back request, which is always there.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^${en.requestCallback}')), findsOneWidget);
    expect(find.textContaining('Ibà'), findsNothing);
  });
}
