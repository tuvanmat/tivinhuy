import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tv_flutter_app/controllers/movies_controller.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/player_page.dart';
import 'package:tv_flutter_app/services/movie_storage_service.dart';
import 'package:tv_flutter_app/utils/navigation.dart';

class MovieDetailScreen extends StatefulWidget {
  final String slug;
  const MovieDetailScreen({super.key, required this.slug});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieModel? _movie;
  bool _isLoading = true;
  bool _isExpanded = false;
  bool _showEpisodes = false;
  bool _isFav = false;

  Map<String, ServerGroupData> _groupedServers = {};
  String _selectedServer = '';
  int _savedEpisodeIndex = 0; // Biến lưu tập đang xem dở từ lịch sử

  final FocusNode _playButtonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isFav = MovieStorageService.isFavorite(widget.slug);

    // Kiểm tra xem phim này đã có lịch sử xem dở chưa
    final progressData = MovieStorageService.getWatchProgress(widget.slug);
    if (progressData != null && progressData.containsKey('episodeIndex')) {
      _savedEpisodeIndex = progressData['episodeIndex'] ?? 0;
    }

    _fetchDetails();
  }

  @override
  void dispose() {
    _playButtonFocusNode.dispose();
    for (var group in _groupedServers.values) {
      for (var epNode in group.episodeNodes) {
        epNode.dispose();
      }
      group.serverNode.dispose();
    }
    super.dispose();
  }

  void _fetchDetails() async {
    try {
      MovieModel? movie = await MoviesController.getMovieDetails(widget.slug)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

      Map<String, List<Map<String, dynamic>>> rawGrouped = {};
      if (movie != null && movie.episodes.isNotEmpty) {
        for (int i = 0; i < movie.episodes.length; i++) {
          final ep = movie.episodes[i];
          final serverName =
              ep.serverName.isNotEmpty ? ep.serverName : 'Server chính';
          if (!rawGrouped.containsKey(serverName)) {
            rawGrouped[serverName] = [];
          }
          rawGrouped[serverName]!.add({
            'episode': ep,
            'index': i,
          });
        }
      }

      Map<String, ServerGroupData> finalizedGroups = {};
      rawGrouped.forEach((serverName, listItems) {
        List<FocusNode> episodeNodes =
            List.generate(listItems.length, (_) => FocusNode());
        FocusNode serverNode = FocusNode();
        finalizedGroups[serverName] = ServerGroupData(
          items: listItems,
          episodeNodes: episodeNodes,
          serverNode: serverNode,
        );
      });

      if (mounted) {
        setState(() {
          _movie = movie;
          _groupedServers = finalizedGroups;
          if (finalizedGroups.isNotEmpty) {
            _selectedServer = finalizedGroups.keys.first;
          }
          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _playButtonFocusNode.canRequestFocus) {
            _playButtonFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải chi tiết phim trong screen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _cleanHtml(String htmlText) {
    if (htmlText.isEmpty) return '';
    return htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _movie == null
              ? const Center(
                  child: Text("Không tìm thấy thông tin phim",
                      style: TextStyle(color: Colors.white)))
              : Stack(
                  children: [
                    // 1. ẢNH NỀN TRÀN VIỀN
                    Positioned.fill(
                      child: Image.network(
                        _movie!.horizontalPhoto.isNotEmpty
                            ? _movie!.horizontalPhoto
                            : _movie!.verticalPhoto,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      ),
                    ),

                    // 2. LỚP GRADIENT PHỦ MỜ
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.9),
                              Colors.black.withValues(alpha: 0.7),
                              Colors.black.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. NỘI DUNG CHI TIẾT
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50.0, vertical: 30.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Tên phim
                                  Text(
                                    _movie!.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Thông tin phụ
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _movie!.quality.isNotEmpty
                                              ? _movie!.quality.toUpperCase()
                                              : "HD",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (_movie!.time.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          _movie!.time,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14),
                                        ),
                                      ],
                                      if (_movie!.year.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        const Text("•",
                                            style: TextStyle(
                                                color: Colors.white70)),
                                        const SizedBox(width: 10),
                                        Text(
                                          _movie!.year,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // GIAO DIỆN KHI CHƯA BẤM XEM NGAY
                                  if (!_showEpisodes) ...[
                                    Row(
                                      children: [
                                        _FocusableActionButton(
                                          title: _savedEpisodeIndex > 0
                                              ? "XEM TIẾP (Tập ${_savedEpisodeIndex + 1})"
                                              : "XEM NGAY",
                                          icon: Icons.play_arrow,
                                          isPrimary: true,
                                          autofocus: true,
                                          focusNode: _playButtonFocusNode,
                                          onPressed: () {
                                            if (_movie!.episodes.isEmpty) {
                                              Navigator.push(
                                                context,
                                                materialNavigationRoute(
                                                  context,
                                                  PlayerPage(
                                                    movieModel: _movie!,
                                                    initialEpisodeIndex: 0,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              // Nếu có lịch sử xem dở, bấm XEM TIẾP sẽ nhảy thẳng vào phát luôn tập đó
                                              if (_savedEpisodeIndex > 0 &&
                                                  _savedEpisodeIndex <
                                                      _movie!.episodes.length) {
                                                Navigator.push(
                                                  context,
                                                  materialNavigationRoute(
                                                    context,
                                                    PlayerPage(
                                                      movieModel: _movie!,
                                                      initialEpisodeIndex:
                                                          _savedEpisodeIndex,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                setState(() {
                                                  _showEpisodes = true;
                                                });
                                                Future.delayed(
                                                    const Duration(
                                                        milliseconds: 100), () {
                                                  if (_groupedServers
                                                      .containsKey(
                                                          _selectedServer)) {
                                                    final sNode =
                                                        _groupedServers[
                                                                _selectedServer]!
                                                            .serverNode;
                                                    if (sNode.canRequestFocus) {
                                                      sNode.requestFocus();
                                                    }
                                                  }
                                                });
                                              }
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 15),
                                        _FocusableActionButton(
                                          title:
                                              _isFav ? "Đã thích" : "Yêu thích",
                                          icon: _isFav
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          isPrimary: false,
                                          onPressed: () async {
                                            if (_movie != null) {
                                              await MovieStorageService
                                                  .toggleFavorite(_movie!);
                                              setState(() {
                                                _isFav = MovieStorageService
                                                    .isFavorite(widget.slug);
                                              });

                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(_isFav
                                                      ? "Đã thêm vào danh sách yêu thích"
                                                      : "Đã xóa khỏi yêu thích"),
                                                  duration: const Duration(
                                                      seconds: 1),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: 600,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _cleanHtml(_movie!.description),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 15,
                                              height: 1.4,
                                            ),
                                            maxLines: _isExpanded ? 10 : 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          _FocusableTextButton(
                                            title: _isExpanded
                                                ? "Thu gọn ▲"
                                                : "Xem thêm ▼",
                                            onPressed: () {
                                              setState(() {
                                                _isExpanded = !_isExpanded;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    // GIAO DIỆN CHỌN MÁY CHỦ & TẬP PHIM
                                    const Text(
                                      "Chọn phiên bản / Máy chủ:",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // HÀNG NGANG CHỌN MÁY CHỦ
                                    SizedBox(
                                      height: 42,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        children: _groupedServers.keys
                                            .toList()
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final int index = entry.key;
                                          final String serverName = entry.value;
                                          final isSelected =
                                              _selectedServer == serverName;
                                          final groupData =
                                              _groupedServers[serverName]!;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12),
                                            child: _ServerTabButton(
                                              title: serverName,
                                              isSelected: isSelected,
                                              autofocus: index == 0,
                                              focusNode: groupData.serverNode,
                                              onPressed: () {
                                                setState(() {
                                                  _selectedServer = serverName;
                                                });
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // DANH SÁCH TẬP PHIM HIỂN THỊ PHÍA DƯỚI DỰA THEO MÁY CHỦ ĐANG CHỌN/FOCUS
                                    Text(
                                      "Danh sách tập ($_selectedServer):",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    SizedBox(
                                      height: 160,
                                      width: 700,
                                      child: GridView.builder(
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 4,
                                          childAspectRatio: 2.5,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                        itemCount:
                                            _groupedServers[_selectedServer]
                                                    ?.items
                                                    .length ??
                                                0,
                                        itemBuilder: (context, index) {
                                          final groupData =
                                              _groupedServers[_selectedServer]!;
                                          final item = groupData.items[index];
                                          final ep =
                                              item['episode'] as EpisodeModel;
                                          final originalIndex =
                                              item['index'] as int;
                                          final epNode =
                                              groupData.episodeNodes[index];

                                          return _EpisodeTile(
                                            title: ep.name,
                                            focusNode: epNode,
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                materialNavigationRoute(
                                                  context,
                                                  PlayerPage(
                                                    movieModel: _movie!,
                                                    initialEpisodeIndex:
                                                        originalIndex,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class ServerGroupData {
  final List<Map<String, dynamic>> items;
  final List<FocusNode> episodeNodes;
  final FocusNode serverNode;

  ServerGroupData({
    required this.items,
    required this.episodeNodes,
    required this.serverNode,
  });
}

class _FocusableActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isPrimary;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  const _FocusableActionButton({
    required this.title,
    required this.icon,
    required this.isPrimary,
    this.autofocus = false,
    this.focusNode,
    required this.onPressed,
  });

  bool _isActionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _isActionKey(event.logicalKey)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: hasFocus
                    ? Colors.white
                    : (isPrimary ? Colors.white : Colors.white24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus ? Colors.amber : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: hasFocus
                        ? Colors.black
                        : (isPrimary ? Colors.black : Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: hasFocus
                          ? Colors.black
                          : (isPrimary ? Colors.black : Colors.white),
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

class _FocusableTextButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _FocusableTextButton({required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasFocus ? Colors.white24 : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: hasFocus ? Colors.amber : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServerTabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  const _ServerTabButton({
    required this.title,
    required this.isSelected,
    this.autofocus = false,
    this.focusNode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onPressed();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: hasFocus
                    ? Colors.white
                    : (isSelected ? Colors.redAccent : Colors.grey[850]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasFocus ? Colors.amber : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                title,
                style: TextStyle(
                  color: hasFocus ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final String title;
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  const _EpisodeTile({
    required this.title,
    this.focusNode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasFocus ? Colors.white : Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus ? Colors.amber : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                title,
                style: TextStyle(
                  color: hasFocus ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}
