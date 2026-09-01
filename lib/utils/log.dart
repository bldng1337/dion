import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

const kLogSourceMain = 'main';
const kLogSourceBackground = 'background';

final logger = Logger(
  printer: HybridPrinter(
    SimplePrinter(),
    error: PrettyPrinter(),
    fatal: PrettyPrinter(),
    warning: PrettyPrinter(),
  ),
  filter: ProductionFilter(),
  output: MultiOutput([ConsoleOutput(), StoreLogOutput()]),
);

/// Feeds raw, unrendered [LogEvent]s into the [LogStore].
///
/// Terminal decoration stays in the printer; the store only ever sees the
/// structured record so the UI and clipboard formatting can render it
/// themselves.
class StoreLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) => LogStore.instance.add(event.origin);
}

/// A single structured log entry as persisted on disk and shown in the UI.
@immutable
class LogRecord {
  final DateTime time;
  final Level level;
  final String message;
  final String? error;
  final String? stackTrace;

  /// Which isolate emitted the record: [kLogSourceMain] or
  /// [kLogSourceBackground].
  final String source;

  const LogRecord({
    required this.time,
    required this.level,
    required this.message,
    required this.source,
    this.error,
    this.stackTrace,
  });

  factory LogRecord.fromEvent(LogEvent event, {required String source}) {
    return LogRecord(
      time: event.time,
      level: event.level,
      message: _stringify(event.message),
      source: source,
      error: event.error?.toString(),
      stackTrace: event.stackTrace?.toString(),
    );
  }

  static String _stringify(dynamic message) {
    if (message is String) return message;
    try {
      return jsonEncode(message);
    } catch (_) {
      return message.toString();
    }
  }

  Map<String, dynamic> toMap() => {
        'time': time.toIso8601String(),
        'level': level.name,
        'message': message,
        'source': source,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };

  factory LogRecord.fromMap(Map<String, dynamic> map) => LogRecord(
        time: DateTime.parse(map['time'] as String),
        level: Level.values.firstWhere(
          (level) => level.name == map['level'],
          orElse: () => Level.info,
        ),
        message: map['message'] as String? ?? '',
        source: map['source'] as String? ?? kLogSourceMain,
        error: map['error'] as String?,
        stackTrace: map['stackTrace'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogRecord &&
          other.time == time &&
          other.level == level &&
          other.message == message &&
          other.error == error &&
          other.stackTrace == stackTrace &&
          other.source == source;

  @override
  int get hashCode =>
      Object.hash(time, level, message, error, stackTrace, source);
}

/// Single-line clipboard/export representation of a [LogRecord].
String formatLogRecord(LogRecord record) {
  final buffer = StringBuffer();
  buffer.writeln(
    '[${record.time.toIso8601String()}] [${record.level.name.toUpperCase()}]'
    '${record.source == kLogSourceMain ? '' : ' [${record.source.toUpperCase()}]'}',
  );
  buffer.writeln(record.message);
  if (record.error != null) {
    buffer.writeln('Error: ${record.error}');
  }
  if (record.stackTrace != null) {
    buffer.writeln('Stack trace:');
    buffer.writeln(record.stackTrace);
  }
  buffer.writeln('---');
  return buffer.toString();
}

/// Clipboard/export representation of multiple records, oldest first.
String formatLogRecords(Iterable<LogRecord> records) =>
    records.map(formatLogRecord).join();

/// Structured log sink persisted as JSON lines in the app support directory.
///
/// Both the main and the background (workmanager) isolate run the same store
/// against the same files, which is what surfaces periodic job errors in the
/// running app. The in-memory ring is what the log view renders; the files
/// keep history across restarts, bounded by size-based rotation.
class LogStore extends ChangeNotifier {
  static const _fileName = 'dion.log';

  static final LogStore instance = LogStore();

  final int maxMemoryRecords;
  final int maxFiles;
  final int rotateBytes;

  final List<LogRecord> _records = [];
  final List<String> _pendingLines = [];
  Directory? _dir;
  IOSink? _sink;
  int _bytesSinceOpen = 0;
  Future<void>? _initFuture;
  Future<void> _io = Future.value();

  /// Tag applied to records emitted from this isolate.
  String _source = kLogSourceMain;

  LogStore({
    this.maxMemoryRecords = 1000,
    this.maxFiles = 3,
    this.rotateBytes = 512 * 1024,
  });

  bool get isReady => _initFuture != null;

  /// Completes once the directory has been opened and history loaded.
  Future<void> get ready => _initFuture ?? Future.value();

  /// Waits until all queued writes have hit disk.
  Future<void> get flushed => _io;

  List<LogRecord> get records => List.unmodifiable(_records);

  /// Sets the isolate tag for subsequently added records. The background
  /// isolate sets this before seeding dependencies.
  // ignore: avoid_setters_without_getters
  set source(String value) => _source = value;

  Future<void> init(Directory directory) => _initFuture ??= _init(directory);

  Future<void> _init(Directory directory) async {
    _dir = directory;
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      if (_source == kLogSourceMain) {
        final history = await _loadHistory();
        _records.insertAll(0, history);
        _sink = await _openSink();
      }
      final pending = List.of(_pendingLines);
      _pendingLines.clear();
      for (final line in pending) {
        _enqueueLine(line);
      }
      notifyListeners();
    } catch (e, stack) {
      // Logging must never break the app; degrade to memory-only.
      debugPrint('LogStore init failed: $e\n$stack');
    }
  }

  File _fileFor(int index) => File(
        p.join(_dir!.path, index == 0 ? _fileName : '$_fileName.$index'),
      );

  /// Loads the newest [maxMemoryRecords] records across the current and
  /// rotated files.
  Future<List<LogRecord>> _loadHistory() async {
    final newestFirst = <LogRecord>[];
    for (var index = 0; index < maxFiles; index++) {
      if (newestFirst.length >= maxMemoryRecords) break;
      final file = _fileFor(index);
      if (!await file.exists()) continue;
      try {
        final lines = await file.readAsLines();
        for (final line in lines.reversed) {
          if (newestFirst.length >= maxMemoryRecords) break;
          final record = _tryParseLine(line);
          if (record != null) newestFirst.add(record);
        }
      } catch (_) {
        // Unreadable/partial line or file: skip it, keep the rest.
      }
    }
    return newestFirst.reversed.toList();
  }

  LogRecord? _tryParseLine(String line) {
    if (line.isEmpty) return null;
    try {
      return LogRecord.fromMap(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<IOSink?> _openSink() async {
    // Only the main isolate keeps a long-lived sink; the background isolate
    // appends per write so a concurrent rotation in the main isolate can
    // never strand its open handle on a renamed file.
    if (_source != kLogSourceMain || _dir == null) return null;
    final file = _fileFor(0);
    _bytesSinceOpen = await file.exists() ? await file.length() : 0;
    return file.openWrite(mode: FileMode.append);
  }

  void add(LogEvent event) {
    final record = LogRecord.fromEvent(event, source: _source);
    if (_records.length >= maxMemoryRecords) {
      _records.removeRange(
        0,
        _records.length - maxMemoryRecords + 1,
      );
    }
    _records.add(record);
    final line = jsonEncode(record.toMap());
    if (_initFuture == null) {
      // Directory not opened yet; flush once init completes.
      _pendingLines.add(line);
    } else {
      _enqueueLine(line);
    }
    notifyListeners();
  }

  void _enqueueLine(String line) {
    _io = _io.then((_) => _writeLine(line));
  }

  Future<void> _writeLine(String line) async {
    if (_dir == null) return;
    try {
      if (_source == kLogSourceMain) {
        // Reopened lazily so e.g. clear() does not immediately recreate the
        // file it just deleted.
        _sink ??= await _openSink();
        if (_bytesSinceOpen >= rotateBytes) {
          await _rotate();
        }
        _sink!.writeln(line);
        _bytesSinceOpen += line.length + 1;
        await _sink!.flush();
      } else {
        final file = _fileFor(0);
        if (await file.exists() && await file.length() >= rotateBytes) {
          await _rotate();
        }
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('LogStore write failed: $e');
    }
  }

  Future<void> _rotate() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
    }
    for (var index = maxFiles - 2; index >= 1; index--) {
      final from = _fileFor(index);
      final to = _fileFor(index + 1);
      if (!await from.exists()) continue;
      if (await to.exists()) {
        await to.delete();
      }
      await from.rename(to.path);
    }
    final current = _fileFor(0);
    if (await current.exists()) {
      await current.rename(_fileFor(1).path);
    }
    _bytesSinceOpen = 0;
    _sink = await _openSink();
  }

  Future<void> clear() async {
    _records.clear();
    _pendingLines.clear();
    notifyListeners();
    _io = _io.then((_) async {
      try {
        if (_sink != null) {
          await _sink!.close();
          _sink = null;
        }
        for (var index = 0; index < maxFiles; index++) {
          final file = _fileFor(index);
          if (await file.exists()) {
            await file.delete();
          }
        }
        _bytesSinceOpen = 0;
      } catch (e) {
        debugPrint('LogStore clear failed: $e');
      }
    });
  }

  Future<void> close() => _io = _io.then((_) async {
        await _sink?.flush();
        await _sink?.close();
        _sink = null;
      });
}
