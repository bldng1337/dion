abstract class TreeNode<Self extends TreeNode<Self>> {
  // Self extends TreeNode<Self> ensures the implementing class returns its own type
  Iterable<Self> get children;

  Iterable<Self> traverseBreathFirst({bool includeSelf = true}) sync* {
    if (includeSelf) {
      yield this as Self;
    }
    for (final child in children) {
      yield* child.traverseBreathFirst(includeSelf: true);
    }
  }

  void traverseWhere(bool Function(Self node) f) {
    if (!f(this as Self)) {
      return;
    }
    for (final child in children) {
      child.traverseWhere(f);
    }
  }

  Iterable<Self> traverseDepthFirst({bool includeSelf = true}) sync* {
    for (final child in children) {
      yield* child.traverseDepthFirst(includeSelf: true);
    }
    if (includeSelf) {
      yield this as Self;
    }
  }

  T map<T>(T Function(Self node, List<T> children) f) {
    return f(this as Self, children.map((e) => e.map(f)).toList());
  }
}
