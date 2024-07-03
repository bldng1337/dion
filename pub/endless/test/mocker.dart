import 'dart:async';

class MockItemBatcher {
  int batchIndex = 0;
  final int batchSize;

  MockItemBatcher({
    this.batchSize = 5,
  });

  List<MockItem> nextBatch() {
    List<MockItem> batch = [];

    for (int i = 0; i < batchSize; i++) {
      batch.add(MockItem(title: 'Item ${batchIndex * batchSize + i}'));
    }

    batchIndex += 1;

    return batch;
  }
}

class MockItemBloc {
  final StreamController<List<MockItem>> _controller = StreamController();
  late final MockItemBatcher batcher;
  final int batchSize;

  MockItemBloc({
    this.batchSize = 5,
  }) {
    batcher = MockItemBatcher(batchSize: batchSize);
  }

  final delayDuration = const Duration(milliseconds: 500);

  Stream<List<MockItem>> get stream {
    return _controller.stream;
  }

  load() {
    // Delay the loading of the next batch to simulate real data fetching
    Future.delayed(
      delayDuration,
      () => _controller.add(batcher.nextBatch()),
    );
  }
}

class MockItem {
  final String title;

  MockItem({required this.title});
}
