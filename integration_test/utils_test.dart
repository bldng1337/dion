import 'dart:io';

import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/cache.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/ratelimit.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/tree.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inline_result/inline_result.dart';
import 'package:path/path.dart';

void main() {
  group('Utils', () {
    group('Async', () {
      test('Completable completes with value', () async {
        final completable = Completable<int>();
        completable.complete(42);
        expect(completable.isCompleted, isTrue);
        expect(await completable.future, 42);
        expect(completable.value, 42);
      });

      test('Completable completes with future', () async {
        final completable = Completable<int>();
        completable.complete(Future.value(42));
        expect(completable.isCompleted, isFalse);
        await completable.future;
        expect(completable.isCompleted, isTrue);
        expect(await completable.future, 42);
        expect(completable.value, 42);
      });

      test('Completable completes with error', () async {
        final completable = Completable<int>();
        final error = Exception('Test Error');
        completable.completeError(error);
        expect(completable.isCompleted, isTrue);
        expect(completable.future, throwsA(isA<Exception>()));
        expect(completable.value, isNull);
      });
    });

    group('Cache', () {
      test('DionMapCache basic get and put', () async {
        final cache = DionMapCache<num, num>.fromsize(
          maximumSize: 10,
          loader: (key) async => key * 2,
        );

        final result = await cache.get(5);
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull, 10);
        expect(cache.containsKey(5), isTrue);
        expect(cache.getValue(5)?.getOrNull, 10);
      });

      test('DionMapCache cache bust', () async {
        var loadCount = 0;
        final cache = DionMapCache<num, num>.fromsize(
          maximumSize: 10,
          loader: (key) async {
            loadCount++;
            return key * loadCount;
          },
        );

        var result = await cache.get(5);
        expect(result.getOrNull, 5);
        expect(loadCount, 1);

        result = await cache.get(5);
        expect(result.getOrNull, 5);
        expect(loadCount, 1);

        result = await cache.get(5, cachebust: true);
        expect(result.getOrNull, 10);
        expect(loadCount, 2);
      });

      test('DionMapCache invalidator', () async {
        final cache = DionMapCache<num, DateTime>.fromsize(
          maximumSize: 10,
          loader: (key) async => DateTime.now(),
          invalidator: (key, duration) =>
              duration > const Duration(milliseconds: 100),
        );

        final result1 = await cache.get(1);
        await Future.delayed(const Duration(milliseconds: 110));
        final result2 = await cache.get(1);

        expect(result1.getOrNull, isNot(result2.getOrNull));
      });
    });

    group('FileUtils', () {
      test('File extension', () {
        final file = File('test.txt');
        expect(file.extension, '.txt');
      });

      test('File filename', () {
        final file = File(join('path', 'to', 'test.txt'));
        expect(file.filename, 'test.txt');
      });

      test('File silbling', () {
        final file = File(join('path', 'to', 'test.txt'));
        final sibling = file.silbling('sibling.txt');
        expect(sibling.path, join('path', 'to', 'sibling.txt'));
      });

      test('File twin', () {
        final file = File(join('path', 'to', 'test.txt'));
        final twin = file.twin('.twin');
        expect(twin.path, join('path', 'to', 'test.twin'));
      });
    });

    group('Ratelimit', () {
      test('LeakyBucketRatelimit allows requests within limit', () {
        final ratelimit = LeakyBucketRatelimit(5, const Duration(seconds: 1));
        for (var i = 0; i < 5; i++) {
          expect(ratelimit.tryAcquire(), isTrue);
        }
        expect(ratelimit.tryAcquire(), isFalse);
      });

      test('LeakyBucketRatelimit refills over time', () async {
        final ratelimit = LeakyBucketRatelimit(
          5,
          Duration(milliseconds: (100 / 5).ceil()),
        );
        for (var i = 0; i < 5; i++) {
          ratelimit.tryAcquire();
        }
        expect(ratelimit.tryAcquire(), isFalse);
        await Future.delayed(const Duration(milliseconds: 110));
        expect(ratelimit.tryAcquire(), isTrue);
      });
    });

    group('Service', () {
      test('register and locate service', () {
        register<String>('test_service');
        expect(locate<String>(), 'test_service');
        remove<String>();
        expect(() => locate<String>(), throwsA(isA<TypeError>()));
      });

      test('locateAsync waits for service', () async {
        final future = locateAsync<String>();
        register<String>('test_service');
        expect(await future, 'test_service');
        remove<String>();
      });
    });

    group('Settings', () {
      test('Setting notifies listeners on change', () {
        final setting = Setting<int, SettingMetaData<int>>(
          0,
          const SettingMetaData(),
        );
        var listenerCalled = false;
        setting.addListener(() {
          listenerCalled = true;
        });
        setting.value = 1;
        expect(listenerCalled, isTrue);
      });
    });

    group('Tree', () {
      test('traverseBreathFirst includes self', () {
        final node = TestNode(1, []);
        final result = node.traverseBreathFirst().toList();
        expect(result, [node]);
      });

      test('traverseBreathFirst traverses correctly', () {
        final tree = TestNode(1, [
          TestNode(2, []),
          TestNode(3, [TestNode(4, [])]),
        ]);
        final result = tree.traverseBreathFirst().map((e) => e.value).toList();
        expect(result, [1, 2, 3, 4]);
      });

      test('traverseDepthFirst traverses correctly', () {
        final tree = TestNode(1, [
          TestNode(2, []),
          TestNode(3, [TestNode(4, [])]),
        ]);
        final result = tree.traverseDepthFirst().map((e) => e.value).toList();
        expect(result, [2, 4, 3, 1]);
      });
    });
  });
}

class TestNode extends TreeNode<TestNode> {
  final int value;
  @override
  final List<TestNode> children;

  TestNode(this.value, this.children);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestNode &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
