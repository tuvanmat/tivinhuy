import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/movie_detail_screen.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/services/movie_storage_service.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/navigation.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/home/home_gradient.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<MovieModel> _favoriteMovies = [];
  final FocusNode _clearAllButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _clearAllButtonFocusNode.dispose();
    super.dispose();
  }

  void _loadFavorites() {
    setState(() {
      _favoriteMovies = MovieStorageService.getFavoriteMovies();
    });
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Xóa tất cả', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ danh sách phim yêu thích không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              for (var movie in _favoriteMovies) {
                await MovieStorageService.toggleFavorite(movie);
              }
              _loadFavorites();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Xóa hết',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _returnToHomeSidebar(BuildContext context) {
    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);
    buttonFocusProvider.buttonFocusedLabel = sidebarHomeOption;
    buttonFocusProvider.lastButtonFocusedLabel = sidebarHomeOption;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMultipleMovies = _favoriteMovies.length >= 2;
    final bool hasAnyMovie = _favoriteMovies.isNotEmpty;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final buttonFocusProvider =
              Provider.of<ButtonFocusProvider>(context, listen: false);
          buttonFocusProvider.buttonFocusedLabel = sidebarHomeOption;
          buttonFocusProvider.lastButtonFocusedLabel = sidebarHomeOption;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Phim Yêu Thích Của Bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              // Chỉ hiện dòng mẹo khi có từ 1 phim trở lên
              if (hasAnyMovie) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_rounded,
                      color: Colors.amberAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasMultipleMovies
                          ? 'Mẹo: Nhấn Mũi tên Lên (▲) để xóa phim • Mũi tên Xuống (▼) để xuống nút xóa tất cả'
                          : 'Mẹo: Nhấn Mũi tên Lên (▲) để xóa phim khỏi danh sách này',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _returnToHomeSidebar(context),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 1. Cố định ảnh nền welcome_bg.jpg
            Positioned.fill(
              child: Image.asset(
                'assets/images/welcome_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // 2. Lớp gradient phủ mờ tối
            const HomeGradient(),

            // 3. Nội dung chính
            SafeArea(
              child: _favoriteMovies.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có phim yêu thích nào được lưu.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mqWidth(context, 2),
                        vertical: mqHeigth(context, 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Lưới hiển thị danh sách phim
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 24.0,
                                mainAxisSpacing: 24.0,
                              ),
                              itemCount: _favoriteMovies.length,
                              itemBuilder: (context, index) {
                                final movie = _favoriteMovies[index];
                                final label = "fav_movie_$index";

                                return _FavoriteMovieItem(
                                  movieModel: movie,
                                  label: label,
                                  index: index,
                                  topMovies: _favoriteMovies,
                                  onFavoriteChanged: _loadFavorites,
                                  clearAllFocusNode: _clearAllButtonFocusNode,
                                  hasMultipleMovies: hasMultipleMovies,
                                );
                              },
                            ),
                          ),

                          // Nút Xóa tất cả chỉ xuất hiện khi có từ 2 phim trở lên
                          if (hasMultipleMovies) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: Focus(
                                focusNode: _clearAllButtonFocusNode,
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent ||
                                      event is KeyRepeatEvent) {
                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.select ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.enter ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.space ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.gameButtonA) {
                                      _confirmClearAll(context);
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: Builder(
                                  builder: (context) {
                                    final hasFocus = Focus.of(context).hasFocus;
                                    return InkWell(
                                      onTap: () => _confirmClearAll(context),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: hasFocus
                                              ? Colors.red
                                              : Colors.redAccent
                                                  .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: hasFocus
                                                ? Colors.white
                                                : Colors.redAccent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete_sweep,
                                                color: hasFocus
                                                    ? Colors.white
                                                    : Colors.redAccent,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Xóa Tất Cả Phim Yêu Thích',
                                              style: TextStyle(
                                                color: hasFocus
                                                    ? Colors.white
                                                    : Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Thẻ hiển thị phim chuẩn giao diện trang chủ
class _FavoriteMovieItem extends StatefulWidget {
  final MovieModel movieModel;
  final String label;
  final int index;
  final List<MovieModel> topMovies;
  final VoidCallback onFavoriteChanged;
  final FocusNode clearAllFocusNode;
  final bool hasMultipleMovies;

  const _FavoriteMovieItem({
    required this.movieModel,
    required this.label,
    required this.index,
    required this.topMovies,
    required this.onFavoriteChanged,
    required this.clearAllFocusNode,
    required this.hasMultipleMovies,
  });

  @override
  State<_FavoriteMovieItem> createState() => _FavoriteMovieItemState();
}

class _FavoriteMovieItemState extends State<_FavoriteMovieItem> {
  final FocusNode _itemFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemFocusNode.canRequestFocus) {
          _itemFocusNode.requestFocus();
          final buttonFocusProvider =
              Provider.of<ButtonFocusProvider>(context, listen: false);
          buttonFocusProvider.buttonFocusedLabel = widget.label;
          buttonFocusProvider.lastButtonFocusedLabel = widget.label;
        }
      });
    }
  }

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
    widget.onFavoriteChanged();
  }

  // Hiển thị hộp thoại xóa riêng phim yêu thích này
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        title: const Text(
          'Xóa phim yêu thích',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Bạn có muốn xóa "${widget.movieModel.title}" khỏi danh sách yêu thích không?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await MovieStorageService.toggleFavorite(widget.movieModel);
              widget.onFavoriteChanged();
            },
            child: const Text('Xóa',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              final buttonFocusProvider =
                  Provider.of<ButtonFocusProvider>(context, listen: false);
              buttonFocusProvider.buttonFocusedLabel = widget.label;
              buttonFocusProvider.lastButtonFocusedLabel = widget.label;
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              // Bấm Mũi tên Lên (Arrow Up) để xóa phim này
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _showDeleteDialog(context);
                return KeyEventResult.handled;
              }
              // Bấm Mũi tên Xuống (Arrow Down) chỉ nhảy xuống nút Xóa Tất Cả khi có từ 2 phim trở lên
              if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                  widget.hasMultipleMovies) {
                widget.clearAllFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              // Bấm OK/Select để xem chi tiết phim
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
                                  widget.movieModel.language,
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
    String displayText = text;
    if ((text.contains('Thuyết Minh') || text.contains('Thuyết minh')) &&
        (text.contains('Lồng Tiếng') || text.contains('lồng tiếng'))) {
      displayText = 'TM & Lồng Tiếng';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
