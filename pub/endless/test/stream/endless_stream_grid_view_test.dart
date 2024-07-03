import 'package:endless/stream/endless_stream_controller.dart';
import 'package:endless/stream/endless_stream_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../mocker.dart';

void main() {
  testGoldens(
    'Items state',
    (WidgetTester tester) async {
      await loadAppFonts();

      final bloc = MockItemBloc();

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Items state',
          SizedBox(
            height: 200,
            width: 200,
            child: EndlessStreamGridView<MockItem>(
              loadMore: bloc.load,
              stream: bloc.stream,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
              ),
              itemBuilder: (
                context, {
                required item,
                required index,
                required totalItems,
              }) {
                return Container(
                  color: Colors.purple,
                  child: Text(item.title),
                );
              },
            ),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'grid_items_state',
          customPump: (widget) {
        return widget.pump(bloc.delayDuration);
      });
    },
  );

  testGoldens(
    'Empty state',
    (WidgetTester tester) async {
      await loadAppFonts();

      final bloc = MockItemBloc();

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Empty state',
          SizedBox(
            width: 200,
            height: 200,
            child: EndlessStreamGridView<MockItem>(
              loadMore: bloc.load,
              stream: bloc.stream,
              loadOnSubscribe: false,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
              ),
              itemBuilder: (
                context, {
                required item,
                required index,
                required totalItems,
              }) {
                return Container(
                  color: Colors.purple,
                  child: Text(item.title),
                );
              },
            ),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'grid_empty_state',
          customPump: (widget) {
        return widget.pump(bloc.delayDuration);
      });
    },
  );

  testGoldens(
    'With header, footer and load more builder',
    (WidgetTester tester) async {
      await loadAppFonts();

      final bloc = MockItemBloc();

      final builder = GoldenBuilder.column()
        ..addScenario(
          'With header, footer and load more builder',
          SizedBox(
            width: 200,
            height: 300,
            child: EndlessStreamGridView<MockItem>(
              loadMore: bloc.load,
              stream: bloc.stream,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
              ),
              headerBuilder: (context) {
                return Container(
                  color: Colors.blue,
                  child: const Text('Header'),
                );
              },
              footerBuilder: (context) {
                return Container(
                  color: Colors.red,
                  child: const Text('Footer'),
                );
              },
              loadMoreBuilder: (context) {
                return TextButton(
                  child: const Text('load more'),
                  onPressed: () {},
                );
              },
              itemBuilder: (
                context, {
                required item,
                required index,
                required totalItems,
              }) {
                return Container(
                  color: Colors.purple,
                  child: Text(item.title),
                );
              },
            ),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'grid_header_footer_load_more',
          customPump: (widget) {
        return widget.pump(bloc.delayDuration);
      });
    },
  );

  testGoldens(
    'Loading state',
    (WidgetTester tester) async {
      await loadAppFonts();

      final bloc = MockItemBloc();
      final controller = EndlessStreamController<MockItem>();

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Loading state',
          SizedBox(
            width: 200,
            height: 300,
            child: EndlessStreamGridView<MockItem>(
              loadMore: () => {},
              controller: controller,
              stream: bloc.stream,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
              ),
              headerBuilder: (context) {
                return Container(
                  color: Colors.blue,
                  child: const Text('Header'),
                );
              },
              footerBuilder: (context) {
                return Container(
                  color: Colors.red,
                  child: const Text('Footer'),
                );
              },
              loadMoreBuilder: (context) {
                return TextButton(
                  child: const Text('load more'),
                  onPressed: () {},
                );
              },
              itemBuilder: (
                context, {
                required item,
                required index,
                required totalItems,
              }) {
                return Container(
                  color: Colors.purple,
                  child: Text(item.title),
                );
              },
            ),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'grid_loading_state',
          customPump: (widget) async {
        await widget.pump(Duration.zero);
        controller.loadMore();
        return widget.pump(Duration.zero);
      });
    },
  );

  testGoldens(
    'Load more on scroll',
    (WidgetTester tester) async {
      await loadAppFonts();

      final bloc = MockItemBloc(batchSize: 10);

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Load more on scroll',
          SizedBox(
            // There are two items per row with a total available width of 200. Since the cross axis count is 2,
            // each item gets width 100. The child aspect ratio says that it should be twice as wide as it is tall,
            // so each item gets height 50, making the total row height 50.

            // Since each grid row has height 50 and the MockItemBatcher has batch size of 10,
            // there will be one off screen row below the fold of the scrollview which will be
            // a sufficiently small extentAfter to trigger the next load on scroll since that one last row
            // of height 50 < maxHeight of 200 * extentAfterFactor of default value 0.4
            height: 200,
            width: 200,
            child: EndlessStreamGridView<MockItem>(
              loadMore: bloc.load,
              stream: bloc.stream,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
              ),
              itemBuilder: (
                context, {
                required item,
                required index,
                required totalItems,
              }) {
                return Container(
                  height: 50,
                  color: Colors.red,
                  child: Text(item.title),
                );
              },
            ),
          ),
        );

      await tester.pumpWidgetBuilder(builder.build());

      await screenMatchesGolden(tester, 'grid_load_more_on_scroll',
          customPump: (widget) async {
        // Wait for the initial loadMore call due to loadOnSubscribe
        await widget.pump(bloc.delayDuration);

        // First we scroll once to trigger the load more at the bottom
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0.0, -200));
        await widget.pump(bloc.delayDuration);

        // Then we scroll a second time to get the 2nd batch of items into view
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0.0, -150));
        await widget.pump(bloc.delayDuration);

        // Two batches of items should have been requested
        expect(bloc.batcher.batchIndex, 2);
      });
    },
  );
}
