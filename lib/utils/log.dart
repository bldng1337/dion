import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final logBuffer = MemoryOutput();
final logger = Logger(
  printer: HybridPrinter(
    SimplePrinter(),
    error: PrettyPrinter(),
    fatal: PrettyPrinter(),
    warning: PrettyPrinter(),
  ),
  filter: ProductionFilter(),
  output: MultiOutput([ConsoleOutput(), logBuffer]),
);

class MemoryOutput extends LogOutput with ChangeNotifier {
  final int bufferSize;

  final ListQueue<OutputEvent> buffer;

  void clear() {
    buffer.clear();
    notifyListeners();
  }

  MemoryOutput({this.bufferSize = 20}) : buffer = ListQueue(bufferSize);

  @override
  void output(OutputEvent event) {
    if (buffer.length == bufferSize) {
      buffer.removeFirst();
    }

    buffer.add(event);
    notifyListeners();
  }
}
