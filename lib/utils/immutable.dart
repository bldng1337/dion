extension ImmutableList<T> on List<T> {
  List<T> withIndex(Iterable<int> indexes) {
    return indexes.map((i) => this[i]).toList();
  }

  List<T> withoutIndex(Iterable<int> indexes) {
    return indexed
        .where((i) => !indexes.contains(i.$1))
        .map((e) => e.$2)
        .toList();
  }

  List<T> withNewEntries(Iterable<T> entries) {
    return [...this, ...entries];
  }
}
