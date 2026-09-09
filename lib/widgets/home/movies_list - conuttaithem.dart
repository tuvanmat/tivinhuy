import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/movie_detail_screen.dart';
import 'package:tv_flutter_app/providers/focused_movie_provider.dart';
import 'package:tv_flutter_app/providers/movies_provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/navigation.dart';
import 'package:tv_flutter_app/widgets/common/empty_view.dart';
import 'package:tv_flutter_app/widgets/common/error_view.dart';
import 'package:tv_flutter_app/widgets/common/loading_view.dart';

class MoviesList extends StatefulWidget {
  const MoviesList({super.key});

  @override
  State<MoviesList> createState() => _MoviesListState();
}

class _MoviesListState extends State<MoviesList> {
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  String _lastFetchedType = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final moviesProvider =
          Provider.of<MoviesProvider>(context, listen: false);
      _lastFetchedType = moviesProvider.currentType;
      moviesProvider.readTopMovies().then((movies) {
        if (movies.isNotEmpty) {
          _initializeFocusAndScroll(movies);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeFocusAndScroll(List<MovieModel> movies) {
    if (!mounted) return;
    final focusedMovieProvider =
        Provider.of<FocusedMovieProvider>(context, listen: false);
    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);

    final lastLabel = buttonFocusProvider.buttonFocusedLabel;
    if (lastLabel == "${topMoviesItem}0" || lastLabel.isEmpty) {
      buttonFocusProvider.buttonFocusedLabel = "${topMoviesItem}0";
      buttonFocusProvider.lastButtonFocusedLabel = "${topMoviesItem}0";
      if (movies.isNotEmpty) {
        focusedMovieProvider.focusedMovie = movies.first;
      }
    } else if (lastLabel.startsWith(topMoviesItem)) {
      try {
        final indexStr = lastLabel.replaceFirst(topMoviesItem, '');
        final index = int.parse(indexStr);
        if (index < movies.length) {
          focusedMovieProvider.focusedMovie = movies[index];
        } else {
          focusedMovieProvider.focusedMovie = movies.first;
        }
      } catch (_) {
        focusedMovieProvider.focusedMovie = movies.first;
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    final moviesProvider = Provider.of<MoviesProvider>(context, listen: false);
    final previousLength = moviesProvider.topMovies.length;

    await moviesProvider.loadMoreMovies();

    setState(() {
      _isLoadingMore = false;
    });

    if (mounted && moviesProvider.topMovies.length > previousLength) {
      final buttonFocusProvider =
          Provider.of<ButtonFocusProvider>(context, listen: false);
      final focusedMovieProvider =
          Provider.of<FocusedMovieProvider>(context, listen: false);

      final nextIndex = previousLength;
      buttonFocusProvider.buttonFocusedLabel = "$topMoviesItem$nextIndex";
      buttonFocusProvider.lastButtonFocusedLabel = "$topMoviesItem$nextIndex";
      focusedMovieProvider.focusedMovie = moviesProvider.topMovies[nextIndex];
    }
  }

  // Tinh chỉnh khoảng cách để khi focus vào bất kỳ hàng nào, 
  // hàng đó nằm hiển thị trọn vẹn đầy đủ, không bị lẹm/cắt nửa ở phía trên
  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final rowIndex = index ~/ 5;
    
    const double rowHeight = 280.0;
    
    // Nếu là hàng đầu tiên (rowIndex == 0), ép offset về 0 tuyệt đối.
    // Từ hàng thứ 2 trở xuống, trừ đi một khoảng đệm (ví dụ 35.0 pixel) 
    // để chừa không gian phía trên giúp poster hiển thị đầy đủ không bị che khuất.
    double targetOffset = 0.0;
    if (rowIndex > 0) {
      targetOffset = (rowIndex * rowHeight) - 35.0;
    }

    if (targetOffset != _scrollController.offset) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final moviesProvider = Provider.of<MoviesProvider>(context);

    if (_lastFetchedType != moviesProvider.currentType) {
      _lastFetchedType = moviesProvider.currentType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (moviesProvider.topMovies.isNotEmpty) {
          _initializeFocusAndScroll(moviesProvider.topMovies);
        }
      });
    }

    final itemCount = moviesProvider.topMovies.isEmpty
        ? 0
        : moviesProvider.topMovies.length + 1;

    return SizedBox(
      height: double.infinity,
      child: moviesProvider.loadingTopMovies && moviesProvider.topMovies.isEmpty
          ? const LoadingView(heigth: 5)
          : moviesProvider.errorTopMovies && moviesProvider.topMovies.isEmpty
              ? const ErrorView(heigth: 5)
              : moviesProvider.topMovies.isEmpty
                  ? const EmptyView(heigth: 5)
                  : GridView.builder(
                      controller: _scrollController,
                      shrinkWrap: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 24.0,
                        mainAxisSpacing: 24.0,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index == moviesProvider.topMovies.length) {
                          return _buildLoadMoreCard(context);
                        }

                        final item = moviesProvider.topMovies[index];
                        final label = "$topMoviesItem$index";

                        return MovieListItem(
                          movieModel: item,
                          label: label,
                          index: index,
                          topMovies: moviesProvider.topMovies,
                          onFocusGained: () {
                            _scrollToIndex(index);
                          },
                        );
                      },
                    ),
    );
  }

  Widget _buildLoadMoreCard(BuildContext context) {
    return _LoadMoreItemWidget(
      isLoadingMore: _isLoadingMore,
      onLoadMore: _loadMore,
    );
  }
}

// Widget riêng cho nút Tải thêm phim để quản lý FocusNode chuẩn xác không bị mất focus
class _LoadMoreItemWidget extends StatefulWidget {
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _LoadMoreItemWidget({
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  State<_LoadMoreItemWidget> createState() => _LoadMoreItemWidgetState();
}

class _LoadMoreItemWidgetState extends State<_LoadMoreItemWidget> {
  final FocusNode _loadMoreFocusNode = FocusNode();
  static const String label = "home_load_more_card";

  @override
  void dispose() {
    _loadMoreFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ButtonFocusProvider, String>(
      selector: (context, provider) => provider.buttonFocusedLabel,
      builder: (context, buttonFocusedLabel, _) {
        final focused = buttonFocusedLabel == label;

        if (focused && !_loadMoreFocusNode.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_loadMoreFocusNode.canRequestFocus) {
              _loadMoreFocusNode.requestFocus();
            }
          });
        }

        return Focus(
          focusNode: _loadMoreFocusNode,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              final provider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              provider.buttonFocusedLabel = label;
              provider.lastButtonFocusedLabel = label;
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              final moviesProvider =
                  Provider.of<MoviesProvider>(context, listen: false);

              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (moviesProvider.topMovies.isNotEmpty) {
                  final targetIndex = moviesProvider.topMovies.length - 1;
                  buttonFocusProvider.buttonFocusedLabel =
                      "$topMoviesItem$targetIndex";
                  buttonFocusProvider.lastButtonFocusedLabel =
                      "$topMoviesItem$targetIndex";
                }
                return KeyEventResult.handled;
              }

              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                // Nhảy ngược lên hàng phim phía trên nút tải thêm
                int totalMovies = moviesProvider.topMovies.length;
                int targetIndex = totalMovies - 1 - ((totalMovies - 1) % 5);
                if (targetIndex >= 0 && targetIndex < totalMovies) {
                  buttonFocusProvider.buttonFocusedLabel =
                      "$topMoviesItem$targetIndex";
                  buttonFocusProvider.lastButtonFocusedLabel =
                      "$topMoviesItem$targetIndex";
                }
                return KeyEventResult.handled;
              }

              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                widget.onLoadMore();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            onTap: widget.onLoadMore,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: focused ? Colors.amber : Colors.white24,
                  width: focused ? 3.0 : 1.5,
                ),
              ),
              child: Center(
                child: widget.isLoadingMore
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: focused ? Colors.amber : Colors.white,
                              size: 36),
                          const SizedBox(height: 8),
                          Text(
                            "Tải thêm phim",
                            style: TextStyle(
                              color: focused ? Colors.amber : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MovieListItem extends StatefulWidget {
  final MovieModel movieModel;
  final String label;
  final int index;
  final List<MovieModel> topMovies;
  final VoidCallback onFocusGained;

  const MovieListItem({
    super.key,
    required this.movieModel,
    required this.label,
    required this.index,
    required this.topMovies,
    required this.onFocusGained,
  });

  @override
  State<MovieListItem> createState() => _MovieListItemState();
}

class _MovieListItemState extends State<MovieListItem> {
  final FocusNode _itemFocusNode = FocusNode();

  @override
  void dispose() {
    _itemFocusNode.dispose();
    super.dispose();
  }

  void _openMovieDetail(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);

    buttonFocusProvider.lastButtonFocusedLabel = widget.label;
    buttonFocusProvider.buttonFocusedLabel = widget.label;

    await Navigator.push(
      context,
      materialNavigationRoute(
        context,
        MovieDetailScreen(slug: widget.movieModel.slug),
      ),
    );

    buttonFocusProvider.buttonFocusedLabel = widget.label;
  }

  @override
  Widget build(BuildContext context) {
    final int column = widget.index % 5;
    final String leftLabel =
        column == 0 ? sidebarHomeOption : "$topMoviesItem${widget.index - 1}";

    final String rightLabel = widget.index < widget.topMovies.length - 1
        ? "$topMoviesItem${widget.index + 1}"
        : "home_load_more_card";

    final int topIndex = widget.index - 5;
    final String? topLabel = topIndex >= 0 ? "$topMoviesItem$topIndex" : null;

    final int bottomIndex = widget.index + 5;
    // Kiểm tra xem phim ở hàng dưới có tồn tại không, nếu vượt quá tổng số phim thì chuyển hướng thẳng xuống nút Tải thêm phim
    final bool isLastRow = bottomIndex >= widget.topMovies.length;
    final String bottomLabel =
        isLastRow ? "home_load_more_card" : "$topMoviesItem$bottomIndex";

    return Selector<ButtonFocusProvider, String>(
      selector: (context, buttonFocusProvider) =>
          buttonFocusProvider.buttonFocusedLabel,
      builder: (context, buttonFocusedLabel, _) {
        final focused = buttonFocusedLabel == widget.label;

        if (focused && !_itemFocusNode.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_itemFocusNode.canRequestFocus) {
              _itemFocusNode.requestFocus();
            }
          });
        }

        return Focus(
          focusNode: _itemFocusNode,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              widget.onFocusGained();
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              final focusedMovieProvider =
                  Provider.of<FocusedMovieProvider>(context, listen: false);

              buttonFocusProvider.buttonFocusedLabel = widget.label;
              buttonFocusProvider.lastButtonFocusedLabel = widget.label;
              focusedMovieProvider.focusedMovie = widget.movieModel;
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              final focusedMovieProvider =
                  Provider.of<FocusedMovieProvider>(context, listen: false);

              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                buttonFocusProvider.buttonFocusedLabel = leftLabel;
                buttonFocusProvider.lastButtonFocusedLabel = leftLabel;
                if (column != 0 && widget.index > 0) {
                  focusedMovieProvider.focusedMovie =
                      widget.topMovies[widget.index - 1];
                }
                return KeyEventResult.handled;
              }

              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                buttonFocusProvider.buttonFocusedLabel = rightLabel;
                buttonFocusProvider.lastButtonFocusedLabel = rightLabel;
                if (widget.index < widget.topMovies.length - 1) {
                  focusedMovieProvider.focusedMovie =
                      widget.topMovies[widget.index + 1];
                }
                return KeyEventResult.handled;
              }

              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (topLabel != null &&
                    topIndex >= 0 &&
                    topIndex < widget.topMovies.length) {
                  buttonFocusProvider.buttonFocusedLabel = topLabel;
                  buttonFocusProvider.lastButtonFocusedLabel = topLabel;
                  focusedMovieProvider.focusedMovie =
                      widget.topMovies[topIndex];
                  return KeyEventResult.handled;
                }
              }

              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                buttonFocusProvider.buttonFocusedLabel = bottomLabel;
                buttonFocusProvider.lastButtonFocusedLabel = bottomLabel;
                if (!isLastRow && bottomIndex < widget.topMovies.length) {
                  focusedMovieProvider.focusedMovie =
                      widget.topMovies[bottomIndex];
                }
                return KeyEventResult.handled;
              }

              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                _openMovieDetail(context);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            onTap: () {
              _openMovieDetail(context);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: focused ? Colors.amber : Colors.white70,
                          width: focused ? 3.5 : 1.5,
                        ),
                        boxShadow: focused
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.6),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                )
                              ]
                            : [
                                const BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                )
                              ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FadeInImage(
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 100),
                              placeholder: const AssetImage(
                                "assets/images/loading_image.gif",
                              ),
                              image: NetworkImage(
                                widget.movieModel.verticalPhoto,
                              ),
                            ),
                            if (widget.movieModel.quality.isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: _buildBadge(
                                  widget.movieModel.quality.toUpperCase(),
                                  Colors.redAccent,
                                ),
                              ),
                            if (widget.movieModel.time.isNotEmpty)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: _buildBadge(
                                  widget.movieModel.time,
                                  Colors.black87,
                                ),
                              ),
                            if (widget.movieModel.year.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: _buildBadge(
                                  widget.movieModel.year,
                                  Colors.black87,
                                ),
                              ),
                            if (widget.movieModel.language.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: _buildBadge(
                                  widget.movieModel.language
                                      .replaceAll('Thuyết Minh', 'TM')
                                      .replaceAll('Thuyết minh', 'TM')
                                      .replaceAll('Lồng Tiếng', 'LT')
                                      .replaceAll('Lồng tiếng', 'LT'),
                                  Colors.blue.shade800,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movieModel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: focused ? Colors.amber : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}