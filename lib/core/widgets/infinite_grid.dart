import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A simplified grid widget with basic pagination support
///
/// This is a temporary replacement for the InfiniteGrid widget
/// until the infinite_scroll_pagination package is properly integrated.
class InfiniteGrid<T> extends StatefulWidget {
  /// The page size for pagination
  final int pageSize;

  /// Function to fetch items for a given page
  final Future<List<T>> Function(int pageKey, int pageSize) fetchItems;

  /// Builder function to create a widget for each item
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Widget to display when there are no items
  final Widget? emptyWidget;

  /// Widget to display when there's an error
  final Widget Function(BuildContext context, dynamic error)? errorWidget;

  /// Widget to display while loading the first page
  final Widget? loadingWidget;

  /// Callback when the grid is refreshed
  final Function()? onRefresh;

  /// Scroll controller for the grid
  final ScrollController? scrollController;

  /// Padding for the grid
  final EdgeInsetsGeometry? padding;

  /// Whether to shrink wrap the grid
  final bool shrinkWrap;

  /// Scroll physics for the grid
  final ScrollPhysics? physics;

  /// The number of items in the cross axis
  final int crossAxisCount;

  /// The ratio of the cross-axis to the main-axis extent of each child
  final double childAspectRatio;

  /// The spacing between the items in the cross axis
  final double crossAxisSpacing;

  /// The spacing between the items in the main axis
  final double mainAxisSpacing;

  const InfiniteGrid({
    super.key,
    required this.fetchItems,
    required this.itemBuilder,
    this.pageSize = 20,
    this.emptyWidget,
    this.errorWidget,
    this.loadingWidget,
    this.onRefresh,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 10.0,
    this.mainAxisSpacing = 10.0,
  });

  @override
  State<InfiniteGrid<T>> createState() => _InfiniteGridState<T>();
}

class _InfiniteGridState<T> extends State<InfiniteGrid<T>> {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasError = false;
  dynamic _error;
  bool _hasReachedEnd = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(InfiniteGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the fetch function changes, refresh the grid
    if (oldWidget.fetchItems != widget.fetchItems) {
      _refresh();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _error = null;
    });

    try {
      final items = await widget.fetchItems(0, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(items);
          _isLoading = false;
          _currentPage = 0;
          _hasReachedEnd = items.length < widget.pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _error = e;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || _hasReachedEnd) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final items = await widget.fetchItems(nextPage, widget.pageSize);

      if (mounted) {
        setState(() {
          _items.addAll(items);
          _isLoading = false;
          _currentPage = nextPage;
          _hasReachedEnd = items.length < widget.pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _error = e;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadInitialData();
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return widget.loadingWidget ?? _defaultLoadingWidget(context);
    }

    if (_hasError && _items.isEmpty) {
      return widget.errorWidget != null
          ? widget.errorWidget!(context, _error)
          : _defaultErrorWidget(context);
    }

    if (_items.isEmpty) {
      return widget.emptyWidget ?? _defaultEmptyWidget(context);
    }

    // Create a grid view with the items

    // Create a custom scroll view with a grid
    final gridView = CustomScrollView(
      controller: widget.scrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      slivers: [
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              childAspectRatio: widget.childAspectRatio,
              crossAxisSpacing: widget.crossAxisSpacing,
              mainAxisSpacing: widget.mainAxisSpacing,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              // Load more data when reaching the end
              if (index >= _items.length - widget.crossAxisCount &&
                  !_isLoading &&
                  !_hasReachedEnd) {
                _loadMoreData();
              }

              if (index < _items.length) {
                return widget.itemBuilder(context, _items[index], index);
              } else {
                return const SizedBox.shrink();
              }
            }, childCount: _items.length),
          ),
        ),
        if (_isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: Theme.of(context).primaryColor,
                  size: 30,
                ),
              ),
            ),
          ),
      ],
    );

    return widget.onRefresh != null
        ? RefreshIndicator(onRefresh: _refresh, child: gridView)
        : gridView;
  }

  Widget _defaultEmptyWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 80, color: MlTokens.slate400),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: MlTokens.slate600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 80, color: MlTokens.red400),
            const SizedBox(height: 16),
            Text(
              'Error loading items',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: MlTokens.red600),
            ),
            const SizedBox(height: 8),
            Text(
              _error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: MlTokens.red600),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultLoadingWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: Theme.of(context).primaryColor,
          size: 50,
        ),
      ),
    );
  }
}
