import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/movie_detail_screen.dart';
import 'package:tv_flutter_app/providers/focused_movie_provider.dart';
import 'package:tv_flutter_app/providers/movies_provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/navigation.dart';
import 'package:tv_flutter_app/widgets/common/button_detector_wrapper.dart';
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
                        );
                      },
                    ),
    );
  }

  Widget _buildLoadMoreCard(BuildContext context) {
    const label = "home_load_more_card";

    return Selector<ButtonFocusProvider, String>(
      selector: (context, provider) => provider.buttonFocusedLabel,
      builder: (context, buttonFocusedLabel, _) {
        final focused = buttonFocusedLabel == label;

        return MouseRegion(
          onEnter: (_) {
            final buttonFocusProvider =
                Provider.of<ButtonFocusProvider>(context, listen: false);
            buttonFocusProvider.buttonFocusedLabel = label;
          },
          child: ButtonDetectorWrapper(
            hasFocus: focused,
            onLeftPressed: () {
              final moviesProvider =
                  Provider.of<MoviesProvider>(context, listen: false);
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              if (moviesProvider.topMovies.isNotEmpty) {
                buttonFocusProvider.buttonFocusedLabel =
                    "$topMoviesItem${moviesProvider.topMovies.length - 1}";
              }
            },
            onRightPressed: () {},
            onTopPressed: () {
              final moviesProvider =
                  Provider.of<MoviesProvider>(context, listen: false);
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              int targetIndex = moviesProvider.topMovies.length - 5;
              if (targetIndex >= 0) {
                buttonFocusProvider.buttonFocusedLabel =
                    "$topMoviesItem$targetIndex";
              }
            },
            onBottomPressed: () {},
            onEnterPressed: () {
              _loadMore();
            },
            child: InkWell(
              onTap: _loadMore,
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
                  child: _isLoadingMore
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
          ),
        );
      },
    );
  }
}

class MovieListItem extends StatelessWidget {
  final MovieModel movieModel;
  final String label;
  final int index;
  final List<MovieModel> topMovies;

  const MovieListItem({
    super.key,
    required this.movieModel,
    required this.label,
    required this.index,
    required this.topMovies,
  });

  void _openMovieDetail(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);

    buttonFocusProvider.lastButtonFocusedLabel = label;
    buttonFocusProvider.buttonFocusedLabel = label;

    await Navigator.push(
      context,
      materialNavigationRoute(
        context,
        MovieDetailScreen(slug: movieModel.slug),
      ),
    );

    buttonFocusProvider.buttonFocusedLabel = label;
  }

  @override
  Widget build(BuildContext context) {
    final int column = index % 5;

    final leftLabel =
        column == 0 ? sidebarHomeOption : "$topMoviesItem${index - 1}";

    final rightLabel = index >= topMovies.length - 1
        ? "home_load_more_card"
        : "$topMoviesItem${index + 1}";

    final topIndex = index - 5;
    final String? topLabel = topIndex >= 0 ? "$topMoviesItem$topIndex" : null;

    final bottomIndex = index + 5;
    final String bottomLabel = bottomIndex < topMovies.length
        ? "$topMoviesItem$bottomIndex"
        : "home_load_more_card";

    return Selector<ButtonFocusProvider, String>(
      selector: (context, buttonFocusProvider) =>
          buttonFocusProvider.buttonFocusedLabel,
      builder: (context, buttonFocusedLabel, _) {
        final focused = buttonFocusedLabel == label;

        return MouseRegion(
          onEnter: (_) {
            final buttonFocusProvider =
                Provider.of<ButtonFocusProvider>(context, listen: false);
            final focusedMovieProvider =
                Provider.of<FocusedMovieProvider>(context, listen: false);
            buttonFocusProvider.buttonFocusedLabel = label;
            focusedMovieProvider.focusedMovie = movieModel;
          },
          child: ButtonDetectorWrapper(
            hasFocus: focused,
            onLeftPressed: () {
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              final focusedMovieProvider =
                  Provider.of<FocusedMovieProvider>(context, listen: false);

              buttonFocusProvider.buttonFocusedLabel = leftLabel;

              if (column != 0 && index > 0) {
                focusedMovieProvider.focusedMovie = topMovies[index - 1];
              }
            },
            onRightPressed: () {
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              final focusedMovieProvider =
                  Provider.of<FocusedMovieProvider>(context, listen: false);

              if (index < topMovies.length - 1) {
                focusedMovieProvider.focusedMovie = topMovies[index + 1];
              }

              buttonFocusProvider.buttonFocusedLabel = rightLabel;
            },
            onTopPressed: () {
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);

              if (topLabel != null) {
                buttonFocusProvider.buttonFocusedLabel = topLabel;
                if (topIndex >= 0 && topIndex < topMovies.length) {
                  Provider.of<FocusedMovieProvider>(context, listen: false)
                      .focusedMovie = topMovies[topIndex];
                }
              }
            },
            onBottomPressed: () {
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);

              buttonFocusProvider.buttonFocusedLabel = bottomLabel;
              if (bottomIndex < topMovies.length) {
                Provider.of<FocusedMovieProvider>(context, listen: false)
                    .focusedMovie = topMovies[bottomIndex];
              }
            },
            onEnterPressed: () {
              _openMovieDetail(context);
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
                                fadeInDuration:
                                    const Duration(milliseconds: 100),
                                placeholder: const AssetImage(
                                  "assets/images/loading_image.gif",
                                ),
                                image: NetworkImage(
                                  movieModel.verticalPhoto,
                                ),
                              ),

                              // 1. GÓC TRÊN BÊN TRÁI: Chỉ hiển thị khi có dữ liệu chất lượng thực tế từ API (HD, FHD,...)
                              if (movieModel.quality.isNotEmpty)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: _buildBadge(
                                    movieModel.quality.toUpperCase(),
                                    Colors.redAccent,
                                  ),
                                ),

                              // 2. GÓC TRÊN BÊN PHẢI: Thời lượng
                              if (movieModel.time.isNotEmpty)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: _buildBadge(
                                    movieModel.time,
                                    Colors.black87,
                                  ),
                                ),

                              // 3. GÓC DƯỚI BÊN TRÁI: Năm phát hành
                              if (movieModel.year.isNotEmpty)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: _buildBadge(
                                    movieModel.year,
                                    Colors.black87,
                                  ),
                                ),

                              // 4. GÓC DƯỚI BÊN PHẢI: Ngôn ngữ / Vietsub / Thuyết minh (Đã rút gọn chữ dài)
                              if (movieModel.language.isNotEmpty)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: _buildBadge(
                                    movieModel.language
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
                      movieModel.title,
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
