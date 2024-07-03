/// The pagination controller used to perform actions on the scroll view such as loading more data
/// or clearing its existing items.
class EndlessPaginationController<T> {
  /// Reloads the content of the scroll view, clearing its current data and calling [loadMore].
  late void Function() reload;

  /// Clears the items from the paginated scroll view and resets the current page index.
  late void Function() clear;

  // Loads an additional page of items.
  late void Function() loadMore;

  /// Removes the given item from the scroll view.
  late void Function(T item) remove;

  /// Whether the widget associated with the controller is mounted.
  bool Function() isMounted = () {
    return false;
  };

  EndlessPaginationController();
}
