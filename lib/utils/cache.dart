import 'dart:async';

import 'package:inline_result/inline_result.dart';
import 'package:quiver/cache.dart';
import 'package:quiver/collection.dart';

abstract class CacheValue<T> {
  final DateTime time;
  const CacheValue(this.time);
}

class LoadingEntry<T> extends CacheValue<T> {
  final FutureOr<Result<T>> value;
  const LoadingEntry(super.time, this.value);

  @override
  String toString() {
    return 'LoadingEntry{time: $time, value: $value}';
  }

  @override
  bool operator ==(Object other) =>
      other is LoadingEntry<T> && other.time == time && other.value == value;

  @override
  int get hashCode => Object.hash(time, value);
}

class CacheEntry<T> extends CacheValue<T> {
  final Result<T> value;
  const CacheEntry(super.time, this.value);

  @override
  String toString() {
    return 'CacheEntry{time: $time, value: $value}';
  }

  @override
  bool operator ==(Object other) =>
      other is CacheEntry<T> && other.time == time && other.value == value;

  @override
  int get hashCode => Object.hash(time, value);
}

enum CacheState {
  loading,
  loaded,
  absent,
}

typedef Invalidator<K> = bool Function(K key, Duration duration);

class DionMapCache<K, V> {
  final LruMap<K, CacheValue<V>> map;
  final Loader<K, V> loader;
  final Invalidator<K>? invalidator;

  DionMapCache({required this.map, required this.loader, this.invalidator});

  factory DionMapCache.fromsize({
    required int maximumSize,
    required Loader<K, V> loader,
    Invalidator<K>? invalidator,
  }) {
    return DionMapCache(
      map: LruMap(maximumSize: maximumSize),
      loader: loader,
      invalidator: invalidator,
    );
  }

  Future<Result<V>> get(K key, {bool cachebust = false}) async {
    if (cachebust) {
      invalidate(key);
    }
    if (!map.containsKey(key)) {
      final loading = LoadingEntry(DateTime.now(), loader(key).asResult);
      map[key] = loading;
      final value = await loading.value;
      _promoteEntry(key, loading, value);
      return value;
    }
    final value = map[key]!;
    if (invalidator != null) {
      if (invalidator!(key, DateTime.now().difference(value.time))) {
        invalidate(key);
        return get(key);
      }
    }
    switch (value) {
      case final LoadingEntry<V> loading:
        final value = await loading.value;
        _promoteEntry(key, loading, value);
        return value;
      case final CacheEntry<V> cached:
        return cached.value;
    }
    throw StateError('Unexpected cache entry type ${value.runtimeType}');
  }

  void _promoteEntry(K key, LoadingEntry<V> loading, Result<V> value) {
    if (!map.containsKey(key)) return;
    if (map[key] != loading) return;
    if (invalidator != null) {
      if (invalidator!(key, DateTime.now().difference(loading.time))) {
        invalidate(key);
        return;
      }
    }
    map[key] = CacheEntry(loading.time, value);
  }

  CacheState getState(K key) {
    if (!map.containsKey(key)) {
      return CacheState.absent;
    }
    final value = map[key];
    if (value is LoadingEntry) {
      // There is a small chance that the future is already completed but there should be at least one
      // get() function polling the future and promoting it to a CacheEntry
      // so it would only be incorrect for a short time
      return CacheState.loading;
    }
    if (value is CacheEntry) {
      return CacheState.loaded;
    }
    return CacheState.absent;
  }

  void invalidate(K key) {
    map.remove(key);
  }

  void invalidateAll() {
    map.clear();
  }

  bool containsKey(K key) => map.containsKey(key);

  Result<V>? getValue(K key) {
    final value = map[key];
    if (value is CacheEntry<V>) {
      return value.value;
    }
    return null;
  }

  void preload(K key) {
    if (!map.containsKey(key)) {
      final loading = LoadingEntry(DateTime.now(), loader(key).asResult);
      map[key] = loading;
    }
  }
}
