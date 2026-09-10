import 'package:dionysos/widgets/drawer.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DionDropdown opens a drawer with a checked option on mobile', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // A stateful host, as in the real app: picking an option rebuilds the
    // dropdown with the new value.
    final value = ValueNotifier<int>(1);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<int>(
              valueListenable: value,
              builder: (context, v, _) => DionDropdown<int>(
                value: v,
                items: const [
                  DionDropdownItem(value: 1, label: 'One'),
                  DionDropdownItem(value: 2, label: 'Two'),
                ],
                onChanged: (picked) => value.value = picked!,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The trigger looks like the dropdown button but opens a drawer.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    // The selected option is marked with a check.
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Picking an option closes the drawer and reports the change.
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(value.value, 2);
    expect(find.byIcon(Icons.check), findsNothing);
    // The trigger now shows the picked label.
    expect(find.text('Two'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('DionMultiDropdown toggles items in a drawer on mobile', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DionMultiDropdown<int>(
              defaultItem: const Text('pick'),
              items: [
                MultiDropdownItem(value: 1, label: 'One'),
                MultiDropdownItem.active(value: 2, label: 'Two'),
              ],
              onSelectionChange: (selection) => selected
                ..clear()
                ..addAll(selection),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The selected item ('Two') is shown in the trigger; tapping it opens
    // the drawer.
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);

    // Tapping toggles immediately without closing the drawer.
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('One'),
      ),
      findsOneWidget,
    );
    expect(selected, containsAll([1, 2]));

    // Dismissing the drawer leaves the selection applied; the trigger now
    // shows 'One' as a picked chip.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNothing);
    expect(find.text('One'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('isMobilePlatform tracks the target platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(isMobilePlatform, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(isMobilePlatform, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(isMobilePlatform, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
