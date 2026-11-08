import 'dart:async';

import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';

class _GatedTask extends Task {
  final Completer<void> gate = Completer();
  bool started = false;

  _GatedTask(super.name);

  @override
  Future<void> onRun() {
    started = true;
    return gate.future;
  }

  @override
  Future<void> onCancel() async {}
}

void main() {
  test('draining one queue leaves sibling queues running', () async {
    final manager = TaskManager();
    register<TaskManager>(manager);

    final parent = manager.root.createOrGetCategory(
      'download',
      'Download',
      concurrency: null,
    );
    final firstA = _GatedTask('a');
    final firstB = _GatedTask('b1');
    final secondB = _GatedTask('b2');
    parent.createOrGetCategory('a', 'A').enqueue(firstA);
    final b = parent.createOrGetCategory('b', 'B');
    b.enqueue(firstB);
    b.enqueue(secondB);
    expect(secondB.started, isFalse);

    firstA.gate.complete();
    await pumpEventQueue();
    expect(manager.root.getCategory('download'), same(parent));

    firstB.gate.complete();
    await pumpEventQueue();
    expect(secondB.started, isTrue);

    secondB.gate.complete();
    await pumpEventQueue();
    expect(manager.root.getCategory('download'), isNull);
  });
}
