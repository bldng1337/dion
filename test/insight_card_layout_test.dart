import 'package:dionysos/views/activity/insights/cards/total_tracked_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _chromeKey = Key('card-chrome');

void main() {
  // The insight cards live inside a fixed-height chrome: a Column with a
  // non-flex header and an Expanded body. RenderFlex lays out non-flex
  // children with unbounded main-axis constraints, so anything below a
  // Spacer must not rely on incoming bounds.
  Future<void> pumpInChrome(
    WidgetTester tester,
    Widget Function(BuildContext context) buildBody,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: _chromeKey,
              width: 573,
              height: 150,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hourglass_bottom, size: 13),
                          SizedBox(width: 6),
                          Text('TIME TRACKED'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: Builder(builder: buildBody)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Frame after frame: the first layout is where the unbounded constraints
    // used to abort mid-subtree.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('BarStrip stays within bounded chrome', (tester) async {
    await pumpInChrome(
      tester,
      (context) => BarStrip(
        values: List.generate(30, (i) => Duration(minutes: 30 + i)),
        accent: Colors.green,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TotalTrackedCard lays out inside the card chrome', (
    tester,
  ) async {
    await pumpInChrome(
      tester,
      (context) => const TotalTrackedCard().build(
        context,
        // Not const: the 30-day strip values come from List.generate.
        // ignore: prefer_const_constructors
        TotalTrackedData(
          total: const Duration(days: 45, hours: 4),
          titles: 52,
          episodes: 872,
          last30Days: List.generate(30, (i) => Duration(minutes: 10 + i)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The strip must actually be laid out inside the chrome, not abandoned
    // mid-subtree.
    expect(find.byType(BarStrip), findsOneWidget);
    final chrome = tester.getRect(find.byKey(_chromeKey));
    expect(chrome.contains(tester.getRect(find.byType(BarStrip)).topLeft),
        isTrue);
    expect(chrome.contains(tester.getRect(find.byType(BarStrip)).bottomRight),
        isTrue);
  });
}
