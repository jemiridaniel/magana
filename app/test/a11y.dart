import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every enabled button or switch on screen has a semantics tap action (TalkBack,
/// VoiceOver, Switch Access and Voice Access all need it) and is at least 64 px.
void expectAccessible(WidgetTester tester, String screen) {
  final missing = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    // ignore: deprecated_member_use
    bool has(SemanticsFlag f) => data.hasFlag(f);
    final control =
        has(SemanticsFlag.isButton) || has(SemanticsFlag.hasToggledState);
    final disabled =
        has(SemanticsFlag.hasEnabledState) && !has(SemanticsFlag.isEnabled);
    if (control && !disabled && !data.hasAction(SemanticsAction.tap)) {
      missing.add(data.label);
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  var root = tester.getSemantics(find.byType(Scaffold).last);
  while (root.parent != null) {
    root = root.parent!;
  }
  visit(root);
  expect(missing, isEmpty, reason: '$screen: controls without a tap action');

  for (final b
      in find
          .byWidgetPredicate((w) => w is ButtonStyleButton)
          .hitTestable()
          .evaluate()) {
    final size = b.size!;
    expect(
      size.height >= 64 && size.width >= 64,
      isTrue,
      reason: '$screen: ${b.widget} is $size',
    );
  }
}
