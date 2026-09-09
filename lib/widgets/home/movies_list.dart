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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: FilterButtonWidget(),
        ),
        Expanded(
          child: moviesProvider.loadingTopMovies &&
                  moviesProvider.topMovies.isEmpty
              ? const LoadingView(heigth: 5)
              : moviesProvider.errorTopMovies &&
                      moviesProvider.topMovies.isEmpty
                  ? const ErrorView(heigth: 5)
                  : moviesProvider.topMovies.isEmpty
                      ? const EmptyView(heigth: 5)
                      : GridView.builder(
                          controller: _scrollController,
                          shrinkWrap: false,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 8.0),
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
        ),
      ],
    );
  }

  Widget _buildLoadMoreCard(BuildContext context) {
    return _LoadMoreItemWidget(
      isLoadingMore: _isLoadingMore,
      onLoadMore: _loadMore,
    );
  }
}

class FilterButtonWidget extends StatefulWidget {
  const FilterButtonWidget({super.key});

  @override
  State<FilterButtonWidget> createState() => _FilterButtonWidgetState();
}

class _FilterButtonWidgetState extends State<FilterButtonWidget> {
  final FocusNode _filterFocusNode = FocusNode();

  @override
  void dispose() {
    _filterFocusNode.dispose();
    super.dispose();
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return const FilterDialogContent();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _filterFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            _showFilterDialog(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _filterFocusNode,
        builder: (context, child) {
          final isFocused = _filterFocusNode.hasFocus;
          return InkWell(
            onTap: () => _showFilterDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 140,
              height: 48,
              decoration: BoxDecoration(
                color: isFocused ? Colors.amber : const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune,
                      color: isFocused ? Colors.black : Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Bộ Lọc",
                    style: TextStyle(
                      color: isFocused ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FilterDialogContent extends StatefulWidget {
  const FilterDialogContent({super.key});

  @override
  State<FilterDialogContent> createState() => _FilterDialogContentState();
}

class _FilterDialogContentState extends State<FilterDialogContent> {
  final FocusNode _genreFocusNode = FocusNode();
  final FocusNode _countryFocusNode = FocusNode();
  final FocusNode _yearFocusNode = FocusNode();
  final FocusNode _clearFocusNode = FocusNode();
  final FocusNode _applyFocusNode = FocusNode();

  final List<String> genres = [
    'Tất Cả',
    'Hành Động',
    'Phiêu Lưu',
    'Hoạt Hình',
    'Phim Hài',
    'Hình Sự',
    'Tài Liệu',
    'Chính Kịch',
    'Gia Đình',
    'Giả Tưởng',
    'Lịch Sử',
    'Kinh Dị',
    'Phim Nhạc',
    'Bí Ẩn',
    'Lãng Mạn',
    'Khoa Học Viễn Tưởng',
    'Gây Cấn',
    'Chiến Tranh',
    'Miền Tây',
    'Cổ Trang',
    'Tâm Lý',
    'Phim 18+',
    'Tình Cảm'
  ];

  final List<String> countries = [
    'Tất Cả',
    'Âu Mỹ',
    'Anh',
    'Trung Quốc',
    'Indonesia',
    'Việt Nam',
    'Argentina',
    'Áo',
    'Úc',
    'Bangladesh',
    'Brazil',
    'Bahamas',
    'Belarus',
    'Canada',
    'Thụy Sĩ',
    'Bờ Biển Ngà',
    'Chile',
    'Colombia',
    'Costa Rica',
    'Đức',
    'Đan Mạch',
    'Tây Ban Nha',
    'Pháp',
    'Greenland',
    'Hồng Kông',
    'Hàn Quốc',
    'Nhật Bản',
    'Thái Lan',
    'Đài Loan',
    'Nga',
    'Hà Lan',
    'Quốc gia khác',
    'Philippines',
    'Ấn Độ'
  ];

  final List<String> years = [
    'Tất Cả',
    '2026',
    '2025',
    '2024',
    '2023',
    '2022',
    '2021',
    '2020',
    '2019',
    '2018',
    '2017',
    '2016',
    '2015'
  ];

  String _selectedGenre = 'Tất Cả';
  String _selectedCountry = 'Tất Cả';
  String _selectedYear = 'Tất Cả';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Đưa focus vào dòng Thể Loại đầu tiên khi mở popup
      _genreFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _genreFocusNode.dispose();
    _countryFocusNode.dispose();
    _yearFocusNode.dispose();
    _clearFocusNode.dispose();
    _applyFocusNode.dispose();
    super.dispose();
  }

  void _showSelectionPicker(BuildContext context, String title,
      List<String> items, String currentVal, Function(String) onSelected) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 400,
            height: 480,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chọn $title",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white24, height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = item == currentVal;
                      return _PickerItem(
                        title: item,
                        isSelected: isSelected,
                        autofocus: index == 0,
                        onTap: () {
                          onSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final moviesProvider = Provider.of<MoviesProvider>(context, listen: false);

    return Dialog(
      backgroundColor: const Color(0xFF2D2650),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  "Bộ Lọc Nâng Cao",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),

            // 1. Thể Loại
            _buildOptionRow("Thể Loại", _selectedGenre, _genreFocusNode, () {
              _showSelectionPicker(context, "Thể Loại", genres, _selectedGenre,
                  (val) {
                setState(() => _selectedGenre = val);
              });
            }),

            const Divider(color: Colors.white24),

            // 2. Quốc Gia
            _buildOptionRow("Quốc Gia", _selectedCountry, _countryFocusNode,
                () {
              _showSelectionPicker(
                  context, "Quốc Gia", countries, _selectedCountry, (val) {
                setState(() => _selectedCountry = val);
              });
            }),

            const Divider(color: Colors.white24),

            // 3. Năm Sản Xuất
            _buildOptionRow("Năm Sản Xuất", _selectedYear, _yearFocusNode, () {
              _showSelectionPicker(
                  context, "Năm Sản Xuất", years, _selectedYear, (val) {
                setState(() => _selectedYear = val);
              });
            }),

            const Divider(color: Colors.white24, height: 20),

            // 4. Xóa Tất Cả Bộ Lọc (Đưa lên trên nút Áp dụng)
            Center(
              child: Focus(
                focusNode: _clearFocusNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.space ||
                        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                      setState(() {
                        _selectedGenre = 'Tất Cả';
                        _selectedCountry = 'Tất Cả';
                        _selectedYear = 'Tất Cả';
                      });
                      moviesProvider.clearFilter();
                      Navigator.pop(context);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: AnimatedBuilder(
                  animation: _clearFocusNode,
                  builder: (context, child) {
                    final focused = _clearFocusNode.hasFocus;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedGenre = 'Tất Cả';
                          _selectedCountry = 'Tất Cả';
                          _selectedYear = 'Tất Cả';
                        });
                        moviesProvider.clearFilter();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6.0, horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: focused ? Colors.white24 : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "— Xóa Tất Cả Bộ Lọc —",
                          style: TextStyle(
                            color: focused ? Colors.amber : Colors.white70,
                            fontSize: 14,
                            fontWeight:
                                focused ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 5. Nút Áp Dụng Bộ Lọc (Đưa xuống dưới cùng)
            _buildActionOption("Áp Dụng Bộ Lọc", _applyFocusNode, () {
              moviesProvider.applyFilter(
                genre: _selectedGenre,
                country: _selectedCountry,
                year: _selectedYear,
              );
              Navigator.pop(context);
            }, isHighlighted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOption(
      String title, FocusNode focusNode, VoidCallback onTap,
      {bool isHighlighted = false}) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final focused = focusNode.hasFocus;
          return InkWell(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
              decoration: BoxDecoration(
                color: focused
                    ? Colors.amber
                    : (isHighlighted
                        ? const Color(0xFF1E3A8A)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: focused ? Colors.black : Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: focused ? Colors.black : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionRow(String label, String currentValue, FocusNode focusNode,
      VoidCallback onTap) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final focused = focusNode.hasFocus;
          return InkWell(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              decoration: BoxDecoration(
                color: focused
                    ? Colors.amber.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? Colors.amber : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: focused ? Colors.amber : Colors.white,
                      fontSize: 15,
                      fontWeight: focused ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        currentValue,
                        style: TextStyle(
                          color: focused ? Colors.amber : Colors.greenAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white54, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PickerItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  const _PickerItem({
    required this.title,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
  });

  @override
  State<_PickerItem> createState() => _PickerItemState();
}

class _PickerItemState extends State<_PickerItem> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (context, child) {
          final focused = _focusNode.hasFocus;
          return InkWell(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
              decoration: BoxDecoration(
                color: focused ? Colors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: focused ? Colors.black : Colors.white,
                      fontSize: 15,
                      fontWeight: focused ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (widget.isSelected)
                    Icon(Icons.check,
                        color: focused ? Colors.black : Colors.greenAccent,
                        size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Widget quản lý nút Tải thêm phim ở cuối lưới
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
              Scrollable.ensureVisible(
                context,
                alignment: 0.2,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
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
                          Text(
                            "Như Ý ơi!",
                            style: TextStyle(
                              color: focused ? Colors.amber : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.add_circle,
                            color: focused ? Colors.amber : Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tải thêm phim!",
                            style: TextStyle(
                              color: focused ? Colors.amber : Colors.white,
                              fontSize: 11,
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

  const MovieListItem({
    super.key,
    required this.movieModel,
    required this.label,
    required this.index,
    required this.topMovies,
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

    final slug = widget.movieModel.slug;
    if (slug.isEmpty) {
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
        MovieDetailScreen(slug: slug),
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
              Scrollable.ensureVisible(
                context,
                alignment: 0.15,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return Focus(
          focusNode: _itemFocusNode,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
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
