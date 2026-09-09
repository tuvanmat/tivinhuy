import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/player_page.dart';
import 'package:tv_flutter_app/controllers/movies_controller.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/services/movie_storage_service.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/navigation.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/home/home_gradient.dart';

class ContinueWatchingPage extends StatefulWidget {
  const ContinueWatchingPage({super.key});

  @override
  State<ContinueWatchingPage> createState() => _ContinueWatchingPageState();
}

class _ContinueWatchingPageState extends State<ContinueWatchingPage> {
  List<Map<String, dynamic>> _historyList = [];
  final FocusNode _clearAllButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _clearAllButtonFocusNode.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _historyList = MovieStorageService.getContinueWatchingList();
    });
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Xóa tất cả', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ danh sách xem tiếp không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              for (var item in _historyList) {
                final slug = item['slug'] ?? '';
                if (slug.isNotEmpty) {
                  await MovieStorageService.removeWatchProgress(slug);
                }
              }
              _loadHistory();
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
    final bool hasMultipleMovies = _historyList.length >= 2;
    final bool hasAnyMovie = _historyList.isNotEmpty;

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
                'Phim Đang Xem (Xem Tiếp)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
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
            // 1. Ảnh nền cố định[cite: 14]
            Positioned.fill(
              child: Image.asset(
                'assets/images/welcome_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
            // 2. Gradient tối nền[cite: 14]
            const HomeGradient(),

            // 3. Nội dung lịch sử xem[cite: 14]
            SafeArea(
              child: _historyList.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có lịch sử xem phim nào.',
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
                          // Lưới danh sách phim ở trên
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 24.0,
                                mainAxisSpacing: 24.0,
                              ),
                              itemCount: _historyList.length,
                              itemBuilder: (context, index) {
                                final item = _historyList[index];
                                final slug = item['slug'] ?? '';
                                final title =
                                    item['title'] ?? 'Không có tiêu đề';
                                final poster = item['thumb_url'] ?? '';
                                final quality = item['quality'] ?? '';
                                final year = item['year'] ?? '';
                                final position = item['positionSeconds'] ?? 0.0;
                                final duration = item['durationSeconds'] ?? 0.0;
                                final episodeIndex = item['episodeIndex'] ?? 0;

                                double progress = (duration > 0)
                                    ? (position / duration)
                                    : 0.0;
                                if (progress > 1.0) progress = 1.0;

                                final label = "history_movie_$index";

                                return _HistoryMovieItem(
                                  slug: slug,
                                  title: title,
                                  poster: poster,
                                  quality: quality,
                                  year: year,
                                  progress: progress,
                                  episodeIndex: episodeIndex,
                                  label: label,
                                  index: index,
                                  onHistoryChanged: _loadHistory,
                                  clearAllFocusNode: _clearAllButtonFocusNode,
                                  hasMultipleMovies: hasMultipleMovies,
                                );
                              },
                            ),
                          ),

                          // Nút Xóa tất cả lịch sử chỉ xuất hiện khi có từ 2 phim trở lên
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
                                              'Xóa Tất Cả Lịch Sử Xem',
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

class _HistoryMovieItem extends StatefulWidget {
  final String slug;
  final String title;
  final String poster;
  final String quality;
  final String year;
  final double progress;
  final int episodeIndex;
  final String label;
  final int index;
  final VoidCallback onHistoryChanged;
  final FocusNode clearAllFocusNode;
  final bool hasMultipleMovies;

  const _HistoryMovieItem({
    required this.slug,
    required this.title,
    required this.poster,
    required this.quality,
    required this.year,
    required this.progress,
    required this.episodeIndex,
    required this.label,
    required this.index,
    required this.onHistoryChanged,
    required this.clearAllFocusNode,
    required this.hasMultipleMovies,
  });

  @override
  State<_HistoryMovieItem> createState() => _HistoryMovieItemState();
}

class _HistoryMovieItemState extends State<_HistoryMovieItem> {
  final FocusNode _itemFocusNode = FocusNode();
  bool _isLoadingMovie = false;

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

  // Phát trực tiếp video khi bấm OK[cite: 14]
  void _playDirectly(BuildContext context) async {
    if (_isLoadingMovie) return;
    setState(() {
      _isLoadingMovie = true;
    });

    try {
      MovieModel? movie = await MoviesController.getMovieDetails(widget.slug);

      final progressData = MovieStorageService.getWatchProgress(widget.slug);
      double savedPosition = 0.0;
      if (progressData != null && progressData.containsKey('positionSeconds')) {
        savedPosition = (progressData['positionSeconds'] as num).toDouble();
      }

      if (movie != null && context.mounted) {
        final buttonFocusProvider =
            Provider.of<ButtonFocusProvider>(context, listen: false);
        buttonFocusProvider.lastButtonFocusedLabel = widget.label;
        buttonFocusProvider.buttonFocusedLabel = widget.label;

        await Navigator.push(
          context,
          materialNavigationRoute(
            context,
            PlayerPage(
              movieModel: movie,
              initialEpisodeIndex: widget.episodeIndex,
              initialPositionSeconds: savedPosition,
            ),
          ),
        );

        buttonFocusProvider.buttonFocusedLabel = widget.label;
        widget.onHistoryChanged();
      }
    } catch (e) {
      debugPrint('Lỗi phát nhanh phim từ lịch sử: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMovie = false;
        });
      }
    }
  }

  // Hiển thị hộp thoại xóa phim khỏi danh sách xem tiếp[cite: 14]
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        title: const Text(
          'Xóa lịch sử xem',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Bạn có muốn xóa "${widget.title}" khỏi danh sách xem tiếp không?',
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
              await MovieStorageService.removeWatchProgress(widget.slug);
              widget.onHistoryChanged();
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
              // Bấm phím Mũi tên Lên (Arrow Up) để mở hộp thoại xóa phim này[cite: 14]
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _showDeleteDialog(context);
                return KeyEventResult.handled;
              }
              // Bấm Mũi tên Xuống (Arrow Down) để nhảy xuống nút xóa tất cả nếu có từ 2 phim trở lên[cite: 14]
              if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                  widget.hasMultipleMovies) {
                widget.clearAllFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              // Bấm OK / Enter / Select trên điều khiển để phát phim[cite: 14]
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                _playDirectly(context);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            onTap: () => _playDirectly(context),
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
                              image: NetworkImage(widget.poster),
                            ),
                            if (_isLoadingMovie)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                ),
                              ),
                            if (widget.quality.isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.quality.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.year.isNotEmpty)
                              Positioned(
                                bottom: 12,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.year,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // Thanh tiến trình màu đỏ ở đáy poster[cite: 14]
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                value: widget.progress,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.redAccent),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
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
}
