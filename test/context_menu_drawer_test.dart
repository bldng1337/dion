import 'package:dionysos/widgets/context_menu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SelectionHost extends StatelessWidget {
  const _SelectionHost({required this.selection});

  final ValueNotifier<int> selection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selection,
      builder: (context, count, _) => ContextMenu(
        selectionActive: count > 0,
        selectionCount: count,
        contextItems: [
          ContextMenuItem(
            label: 'Download',
            icon: Icons.download_outlined,
            section: 'Actions',
            onTap: () async {
              selection.value = 0;
            },
          ),
          ContextMenuItem(
            label: 'Select All',
            icon: Icons.select_all,
            section: 'Selection',
            onTap: () async {},
          ),
          ContextMenuItem(
            label: 'Clear Selection',
            icon: Icons.clear_all,
            onTap: () async {
              selection.value = 0;
            },
          ),
        ],
        child: const SizedBox.expand(),
      ),
    );
  }
}

void main() {
  testWidgets('mobile selection drawer opens, refreshes and closes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // The binding asserts foundation debug vars before tear-downs run, so the
    // override has to be cleared within the test body.
    void clearPlatform() => debugDefaultTargetPlatformOverride = null;

    final selection = ValueNotifier<int>(0);
    addTearDown(selection.dispose);

    Widget buildHost() => MaterialApp(
      home: Scaffold(body: _SelectionHost(selection: selection)),
    );

    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);

    // Selecting items opens the drawer with the live count and sections.
    selection.value = 2;
    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('SELECTION'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    // Selecting one more updates the count in the open drawer.
    selection.value = 3;
    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    // An action that clears the selection closes the drawer.
    await tester.tap(find.text('Clear Selection'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
    clearPlatform();
  });

  testWidgets('mobile long press opens the context menu drawer', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextMenu(
            contextItems: [
              ContextMenuItem(label: 'Copy', onTap: () async {}),
              ContextMenuItem(label: 'Paste', onTap: () async {}),
            ],
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    // Tapping the barrier dismisses the drawer.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
