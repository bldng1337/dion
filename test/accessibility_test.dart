import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsData, SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// SemanticsFlag.index is the power-of-two bit itself (e.g. 1 << 3).
bool _hasFlag(SemanticsData data, SemanticsFlag flag) =>
    // ignore: deprecated_member_use
    (data.flags & flag.index) != 0;

bool _hasAction(SemanticsData data, SemanticsAction action) =>
    (data.actions & action.index) != 0;

void main() {
  testWidgets('DionIconbutton exposes tooltip as semantic label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DionIconbutton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('DionIconbutton keeps a 40x40 minimum tap target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DionIconbutton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back, size: 14),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DionIconbutton)), const Size(40, 40));
  });

  testWidgets('DionIconbutton exposes tooltip on cupertino theme', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      InheritedDionTheme(
        theme: DionTheme.cupertino,
        child: MaterialApp(
          home: Scaffold(
            body: DionIconbutton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Clickable exposes button semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Clickable(
              onTap: () {},
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('Some entry'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The button flag lives on the merged semantics node at or above the
    // Clickable's render object, so inspect the whole ancestor chain.
    SemanticsNode? node = tester.getSemantics(find.byType(Clickable));
    var isButton = false;
    var label = '';
    var hasTap = false;
    while (node != null) {
      final data = node.getSemanticsData();
      if (_hasFlag(data, SemanticsFlag.isButton)) isButton = true;
      if (data.label.contains('Some entry')) label = data.label;
      if (_hasAction(data, SemanticsAction.tap)) hasTap = true;
      node = node.parent;
    }
    expect(isButton, isTrue);
    expect(label, isNotEmpty);
    expect(hasTap, isTrue);
    semantics.dispose();
  });

  testWidgets('Clickable activates via Enter and Space keys', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Clickable(
              onTap: () => taps++,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('Some entry'),
              ),
            ),
          ),
        ),
      ),
    );
    // Focus the only focusable node via keyboard traversal.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('Clickable still activates on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Clickable(
              onTap: () => taps++,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Text('Some entry'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Some entry'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('DionTextbutton without onPressed is disabled in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DionTextbutton(child: Text('Disabled'))),
      ),
    );
    await tester.pumpAndSettle();
    final data = tester.getSemantics(find.text('Disabled')).getSemanticsData();
    expect(_hasFlag(data, SemanticsFlag.hasEnabledState), isTrue);
    expect(_hasFlag(data, SemanticsFlag.isEnabled), isFalse);
    expect(_hasAction(data, SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('DionTextbutton with onPressed is enabled in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DionTextbutton(onPressed: () {}, child: const Text('Enabled')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final data = tester.getSemantics(find.text('Enabled')).getSemanticsData();
    expect(_hasFlag(data, SemanticsFlag.isEnabled), isTrue);
    expect(_hasAction(data, SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('ActionButton without onPressed is disabled in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButton: ActionButton(child: Icon(Icons.add)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    var hasEnabledState = false;
    var enabled = false;
    var hasTap = false;
    SemanticsNode? node = tester.getSemantics(find.byIcon(Icons.add));
    while (node != null) {
      final data = node.getSemanticsData();
      if (_hasFlag(data, SemanticsFlag.hasEnabledState)) hasEnabledState = true;
      if (_hasFlag(data, SemanticsFlag.isEnabled)) enabled = true;
      if (_hasAction(data, SemanticsAction.tap)) hasTap = true;
      node = node.parent;
    }
    expect(hasEnabledState, isTrue);
    expect(enabled, isFalse);
    expect(hasTap, isFalse);
    semantics.dispose();
  });

  testWidgets('ActionButton with onPressed is enabled in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: ActionButton(
            onPressed: () async {},
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    var enabled = false;
    var hasTap = false;
    SemanticsNode? node = tester.getSemantics(find.byIcon(Icons.add));
    while (node != null) {
      final data = node.getSemanticsData();
      if (_hasFlag(data, SemanticsFlag.isEnabled)) enabled = true;
      if (_hasAction(data, SemanticsAction.tap)) hasTap = true;
      node = node.parent;
    }
    expect(enabled, isTrue);
    expect(hasTap, isTrue);
    semantics.dispose();
  });
}
