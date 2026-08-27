import 'dart:async';
import 'dart:collection';

import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/tree.dart';
import 'package:flutter/widgets.dart';

enum TaskStatus { idle, running, error }

class TaskCategory extends TreeNode<TaskCategory> {
  final String name;
  final String id;
  final TaskCategory? parent;

  int? concurrency;

  int _runningTasks = 0;
  final List<TaskCategory> _children = [];
  final List<Task> _tasks = [];

  TaskCategory(this.name, this.id, this.parent, {this.concurrency = 1});

  @override
  Iterable<TaskCategory> get children =>
      Iterable.withIterator(() => _children.iterator);
  Iterable<Task> get tasks => Iterable.withIterator(() => _tasks.iterator);

  TaskCategory createOrGetCategory(
    String id,
    String name, {
    int? concurrency = 1,
  }) {
    final cat = getCategory(id);
    if (cat != null) return cat;
    final newcat = TaskCategory(name, id, this);
    newcat.concurrency = concurrency;
    _children.add(newcat);
    return newcat;
  }

  TaskCategory? getCategory(String id) =>
      children.where((e) => e.id == id).firstOrNull;

  void enqueue(Task task) {
    if (task.category != null) {
      throw StateError('Cannot enqueue an already enqueued task');
    }
    if (task.finished) {
      throw StateError('Cannot enqueue a finished task');
    }
    if (task.running) {
      throw StateError('Task is already running');
    }
    _tasks.add(task);
    task.category = this;
    final mngr = locate<TaskManager>();
    mngr._onEnqueue();
  }

  void _dequeue(Task task) {
    if (!_tasks.remove(task)) return; // already gone, nothing to prune
    var cat = this;
    while (cat.parent != null && cat.tasks.isEmpty) {
      cat.parent!._children.remove(cat);
      cat = cat.parent!;
    }
    final mngr = locate<TaskManager>();
    mngr._onDequeue();
  }
}

abstract class Task extends ChangeNotifier {
  final String name;
  TaskCategory? category;
  DateTime created = DateTime.now();

  bool finished = false;
  bool running = false;
  bool _cancelRequested = false;
  Object? error;
  Future<void>? task;

  String _status = 'Pending';
  String get status => _status;
  set status(String value) {
    _status = value;
    notifyListeners();
  }

  double? _progress;
  double? get progress => _progress;

  set progress(double? value) {
    _progress = value;
    notifyListeners();
    locate<TaskManager>().notifyListeners();
  }

  TaskStatus get taskstatus {
    if (error != null) {
      return TaskStatus.error;
    }
    if (running) {
      return TaskStatus.running;
    }
    return TaskStatus.idle;
  }

  Task(this.name);

  void clearError() {
    error = null;
  }

  void run() {
    if (running) return;
    _cancelRequested = false;
    status = 'Starting';
    finished = false;
    running = true;
    error = null;
    notifyListeners();
    task = onRun();
    task!
        .then((value) {
          finished = true;
          running = false;
          notifyListeners();
          category?._dequeue(this);
        })
        .catchError((e, stack) {
          running = false;
          if (_cancelRequested) {
            // The failure is just the cancellation surfacing through onRun.
            finished = true;
            logger.d('Task "$name" was cancelled');
            return null;
          }
          error = e;
          finished = false;
          onFailed(e);
          logger.e(e, stackTrace: stack is StackTrace ? stack : null);
          final mngr = locate<TaskManager>();
          mngr.update();
          mngr.notifyListeners();
          notifyListeners();
        });
  }

  void cancel() {
    if (!running || _cancelRequested) return;
    _cancelRequested = true;
    onCancel().then((_) {
      finished = true;
      running = false;
      notifyListeners();
      category?._dequeue(this);
    });
  }

  /// Removes a queued or failed task from its queue without running it.
  void dismiss() {
    if (running) return;
    _cancelRequested = true; // ignore stragglers of a previous run
    finished = true;
    notifyListeners();
    category?._dequeue(this);
  }

  Future<void> onRun();
  Future<void> onCancel();
  void onFailed(Object? error) {}
}

class TaskManager extends ChangeNotifier {
  // The root must not cap concurrency: it would globally serialize every
  // queue, since any single running task immediately saturates the root
  // and stops the scheduler from starting anything else.
  final TaskCategory _root = TaskCategory(
    'Tasks',
    'root',
    null,
    concurrency: null,
  );

  TaskCategory get root => _root;

  void _onDequeue() {
    update();
    notifyListeners();
  }

  void _onEnqueue() {
    update();
    notifyListeners();
  }

  Stream<Task?> onTaskChange(
    bool Function(Task) filter, {
    List<String>? categoryids,
  }) {
    final controller = StreamController<Task?>();

    Task? last;
    void callback() {
      final current = getTask(filter, categoryids: categoryids);
      if (current == last) return;
      last = current;
      controller.add(current);
    }

    controller.onListen = () {
      last = root
          .traverseBreathFirst()
          .where((cat) => cat.tasks.any(filter))
          .map((cat) => cat.tasks.firstWhere(filter))
          .firstOrNull;
      controller.add(last);
      addListener(callback);
      controller.onCancel = () {
        removeListener(callback);
      };
    };
    return controller.stream;
  }

  void update() {
    for (final cat in root.traverseDepthFirst()) {
      cat._runningTasks =
          cat.tasks.where((e) => e.running).length +
          cat.children.map((e) => e._runningTasks).fold(0, (a, b) => a + b);
    }
    root.traverseWhere((cat) {
      if (cat.concurrency != null && cat._runningTasks >= cat.concurrency!) {
        return false;
      }
      // Start as many tasks as the category (and its ancestors) have free
      // slots for; a single pass used to leave queued siblings waiting even
      // when slots were free.
      while (cat.concurrency == null || cat._runningTasks < cat.concurrency!) {
        final task = cat.tasks
            .where((e) => e.taskstatus == TaskStatus.idle)
            .firstOrNull;
        if (task == null) break;
        task.run();
        TaskCategory? c = cat;
        while (c != null) {
          c._runningTasks++;
          c = c.parent;
        }
      }
      return true;
    });
  }

  static Future<void> ensureInitialized() async {
    register<TaskManager>(TaskManager());
  }

  Task? getTask(bool Function(Task) filter, {List<String>? categoryids}) {
    if (categoryids != null) {
      TaskCategory? cat = root;
      for (final id in categoryids) {
        cat = cat!.getCategory(id);
        if (cat == null) return null;
      }
      return cat!
          .traverseBreathFirst()
          .expand((cat) => cat.tasks)
          .where(filter)
          .firstOrNull;
    }
    return root
        .traverseBreathFirst()
        .expand((cat) => cat.tasks)
        .where(filter)
        .firstOrNull;
  }
}
