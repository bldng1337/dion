import 'package:endless/pagination/endless_pagination_delegate.dart';
import 'package:endless/pagination/endless_pagination_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../mocker.dart';

void main() {
  const pageSize = 5;

  testGoldens(
    'Items state',
    (WidgetTester tester) async {
      await loadAppFonts();

      final batcher = MockItemBatcher(
        batchSize: pageSize,
      );

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Items state',
          EndlessPaginationListView<MockItem>(
            loadMore: (pageIndex) async => batcher.nextBatch(),
            paginationDelegate: EndlessPaginationDelegate(
              pageSize: pageSize,
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
        );

      await tester.pumpWidgetBuilder(builder.build());
      await screenMatchesGolden(tester, 'list_items_state',
          customPump: (widget) {
        return widget.pump(Duration.zero);
      });
    },
  );
}
