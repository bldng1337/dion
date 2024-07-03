/// The stream controller used to perform actions on the stream such as loading more data
/// or clearing its existing items.
class EndlessStreamController<T> {
  /// Removes the given item from the stream's list of items.
  late void Function(T item) remove;

  /// Requests for the next batch of data to be emitted on the stream.
  late void Function() loadMore;

  /// Pauses loading any more data into the stream's list of items, making loadMore() a no-op.
  late void Function() pause;

  /// Resumes loading any more data into the stream's list of items. If the stream is not paused,
  /// behaves as a no-op.
  late void Function() resume;

  /// Clears the items from the stream's list of items. If lazy is specified, it delays clearing
  /// the items until the next time it receives new items.
  late void Function({bool lazy}) clear;

  /// Whether the stream is currently paused.
  late bool Function() isPaused;

  /// Whether the widget associated with the controller is mounted.
  bool Function() isMounted = () {
    return false;
  };

  EndlessStreamController();
}
