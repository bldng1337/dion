/// The delegate that specifies the pagination requirements for the list view such as the maximum
/// number of pages to load and the page size.
class EndlessPaginationDelegate {
  /// The maximum number of pages to load. If unspecified, the scroll view
  /// will support endless scrolling until fewer than [pageSize] items are returned.
  final int? maxPages;

  /// The number of expected items to be returned per page. Used to determine if the scroll view
  /// should stop loading data when fewer than [pageSize] items are returned by the [loadMore] API.
  final int pageSize;

  EndlessPaginationDelegate({
    required this.pageSize,
    this.maxPages,
  });
}
