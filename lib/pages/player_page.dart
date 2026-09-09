import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/providers/player_provider.dart';
import 'package:tv_flutter_app/services/license_service.dart';
import 'package:tv_flutter_app/services/movie_storage_service.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/player/custom_video_player.dart';
import 'package:tv_flutter_app/widgets/player/player_bottom_controls.dart';
import 'package:tv_flutter_app/widgets/player/player_gradient.dart';

class PlayerPage extends StatefulWidget {
  final MovieModel movieModel;
  final int initialEpisodeIndex;
  final double initialPositionSeconds;

  const PlayerPage({
    super.key,
    required this.movieModel,
    this.initialEpisodeIndex = 0,
    this.initialPositionSeconds = 0.0,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late int _currentEpisodeIndex;
  bool _isLeaving = false;
  bool _showEpisodeList = false;
  bool _isCheckingLicense = true; // Trạng thái đang kiểm tra bản quyền
  bool _isAuthorized = false; // Trạng thái được phép xem hay không

  final FocusNode _playerFocusNode = FocusNode();
  final ScrollController _episodesScrollController = ScrollController();

  List<FocusNode> _episodeFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _currentEpisodeIndex = widget.initialEpisodeIndex;
    _initEpisodeFocusNodes();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Kiểm tra bản quyền trước khi cho phép load video
    _verifyLicenseFirst();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playerFocusNode.requestFocus();

      final buttonFocusProvider = Provider.of<ButtonFocusProvider>(
        context,
        listen: false,
      );
      buttonFocusProvider.buttonFocusedLabel = playerPlayOption;
    });
  }

  Future<void> _verifyLicenseFirst() async {
    bool allowed = await LicenseService.checkAppLicense();
    if (!mounted) return;

    setState(() {
      _isAuthorized = allowed;
      _isCheckingLicense = false;
    });

    if (!allowed) {
      // Hiển thị thông báo chặn và khi bấm xác nhận sẽ thoát hẳn ra ngoài
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2430),
          title: const Text(
            'Thông Báo Bản Quyền',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: const Text(
            'Không thể xem phim. Hết thời gian dùng thử hoặc chưa kích hoạt bản quyền.\n\nHãy quay ra trang chủ, vào trang INFO để xem mã Tivi và nhập mã kích hoạt.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Đóng Dialog
                Navigator.of(context).pop(); // Thoát hẳn PlayerPage
              },
              child: const Text(
                'Quay Lại',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _initEpisodeFocusNodes() {
    _episodeFocusNodes.clear();
    for (var i = 0; i < widget.movieModel.episodes.length; i++) {
      _episodeFocusNodes.add(FocusNode(debugLabel: 'EpisodeNode_$i'));
    }
  }

  @override
  void dispose() {
    _playerFocusNode.dispose();
    _episodesScrollController.dispose();
    for (var node in _episodeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _openEpisodeList(PlayerProvider playerProvider) {
    if (widget.movieModel.episodes.length <= 1) return;
    setState(() {
      _showEpisodeList = true;
    });
    playerProvider.activeControls();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentEpisodeIndex < _episodeFocusNodes.length) {
        _episodeFocusNodes[_currentEpisodeIndex].requestFocus();

        if (_episodesScrollController.hasClients) {
          final double targetOffset = (_currentEpisodeIndex * 64.0).clamp(
            0.0,
            _episodesScrollController.position.maxScrollExtent,
          );
          _episodesScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _closeEpisodeList(PlayerProvider playerProvider) {
    setState(() {
      _showEpisodeList = false;
    });
    playerProvider.activeControls();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playerFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Đang kiểm tra bản quyền: hiển thị màn hình chờ màu đen
    if (_isCheckingLicense) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // 2. Nếu chưa được cấp phép: trả về màn hình trống (chờ dialog hiện lên và người dùng bấm thoát)
    if (!_isAuthorized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    // 3. Nếu đã hợp lệ: Cho phép khởi tạo và chạy Video Player bình thường
    return ChangeNotifierProvider(
      create: (_) {
        final provider = PlayerProvider();
        provider.onHideControls = () {
          if (mounted && !_showEpisodeList) {
            _playerFocusNode.requestFocus();
          }
        };

        if (widget.movieModel.episodes.isNotEmpty &&
            _currentEpisodeIndex < widget.movieModel.episodes.length) {
          provider.init(
            widget.movieModel.episodes[_currentEpisodeIndex].linkM3u8,
            initialPositionSeconds: widget.initialPositionSeconds,
          );
        } else {
          provider.init(
            widget.movieModel.url,
            initialPositionSeconds: widget.initialPositionSeconds,
          );
        }

        return provider;
      },
      child: Builder(
        builder: (context) {
          final playerProvider =
              Provider.of<PlayerProvider>(context, listen: false);

          return WillPopScope(
            onWillPop: () async {
              if (_showEpisodeList) {
                _closeEpisodeList(playerProvider);
                return false;
              }
              _leavePlayer(context, playerProvider);
              return false;
            },
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Focus(
                focusNode: _playerFocusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (_showEpisodeList) return KeyEventResult.ignored;
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    if (!playerProvider.controlsVisible) {
                      playerProvider.activeControls();
                      _playerFocusNode.requestFocus();
                    } else {
                      playerProvider.activeControls();
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onTap: () {
                    if (!_showEpisodeList) {
                      playerProvider.activeControls();
                    }
                  },
                  child: Stack(
                    children: [
                      // ẢNH NỀN
                      SizedBox(
                        width: mqWidth(context, 100),
                        height: mqHeigth(context, 100),
                        child: Image.network(
                          widget.movieModel.horizontalPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.black);
                          },
                        ),
                      ),

                      // VIDEO
                      CustomVideoPlayer(
                        videoUrl: (widget.movieModel.episodes.isNotEmpty &&
                                _currentEpisodeIndex <
                                    widget.movieModel.episodes.length)
                            ? widget.movieModel.episodes[_currentEpisodeIndex]
                                .linkM3u8
                            : widget.movieModel.url,
                      ),

                      // CONTROLS
                      Consumer<PlayerProvider>(
                        builder: (context, provider, _) {
                          if (provider.videoPlayerDisposed) {
                            return const SizedBox.shrink();
                          }

                          String movieTitle = widget.movieModel.title;
                          String episodeTitle = '';

                          if (widget.movieModel.episodes.isNotEmpty &&
                              _currentEpisodeIndex <
                                  widget.movieModel.episodes.length) {
                            episodeTitle = widget
                                .movieModel.episodes[_currentEpisodeIndex].name;
                          }

                          final bool showControls =
                              provider.controlsVisible && !_showEpisodeList;

                          if (!showControls) {
                            return const SizedBox.shrink();
                          }

                          return AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Stack(
                              children: [
                                const PlayerGradient(),
                                PlayerBottomControls(
                                  isPlaying: provider.isPlaying,
                                  onBack: provider.goBack,
                                  onForward: provider.goForward,
                                  onPlay: () {
                                    provider.onPlay();
                                  },
                                  episodes: widget.movieModel.episodes,
                                  movieTitle: movieTitle,
                                  episodeTitle: episodeTitle,
                                  quality: widget.movieModel.quality,
                                  onToggleEpisodeList: () {
                                    _openEpisodeList(provider);
                                  },
                                  onEpisodeSelected: (newUrl) async {
                                    if (newUrl.isEmpty ||
                                        provider.changingVideo) {
                                      return;
                                    }
                                    await provider.changeVideo(newUrl);
                                  },
                                  onPreviousEpisode: () async {
                                    if (provider.changingVideo ||
                                        widget.movieModel.episodes.isEmpty) {
                                      return;
                                    }
                                    if (_currentEpisodeIndex <= 0) return;
                                    final int newIndex =
                                        _currentEpisodeIndex - 1;
                                    final String prevUrl = widget
                                        .movieModel.episodes[newIndex].linkM3u8;
                                    if (prevUrl.isEmpty || !mounted) return;
                                    setState(() {
                                      _currentEpisodeIndex = newIndex;
                                    });
                                    _saveProgress(provider);
                                    await provider.changeVideo(prevUrl);
                                  },
                                  onNextEpisode: () async {
                                    if (provider.changingVideo ||
                                        widget.movieModel.episodes.isEmpty) {
                                      return;
                                    }
                                    if (_currentEpisodeIndex >=
                                        widget.movieModel.episodes.length - 1) {
                                      return;
                                    }
                                    final int newIndex =
                                        _currentEpisodeIndex + 1;
                                    final String nextUrl = widget
                                        .movieModel.episodes[newIndex].linkM3u8;
                                    if (nextUrl.isEmpty || !mounted) return;
                                    setState(() {
                                      _currentEpisodeIndex = newIndex;
                                    });
                                    _saveProgress(provider);
                                    await provider.changeVideo(nextUrl);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // PANEL DANH SÁCH TẬP PHIM
                      if (_showEpisodeList &&
                          widget.movieModel.episodes.length > 1)
                        _buildEpisodeListPanel(playerProvider),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeListPanel(PlayerProvider playerProvider) {
    final episodes = widget.movieModel.episodes;
    final String qualityText = widget.movieModel.quality.isNotEmpty
        ? widget.movieModel.quality.toUpperCase()
        : "1080p";

    return Align(
      alignment: Alignment.centerRight,
      child: FocusScope(
        autofocus: true,
        child: Container(
          width: mqWidth(context, 45),
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2430).withValues(alpha: 0.95),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 25,
                spreadRadius: 5,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Danh sách tập",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                qualityText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: _episodesScrollController,
                  itemCount: episodes.length,
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    final isCurrentPlaying = index == _currentEpisodeIndex;

                    if (_episodeFocusNodes.length <= index) {
                      _initEpisodeFocusNodes();
                    }
                    final focusNode = _episodeFocusNodes[index];

                    return Focus(
                      focusNode: focusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent || event is KeyRepeatEvent) {
                          if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowLeft ||
                              event.logicalKey == LogicalKeyboardKey.escape) {
                            _closeEpisodeList(playerProvider);
                            return KeyEventResult.handled;
                          } else if (event.logicalKey ==
                                  LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            _selectEpisode(
                                index, episode.linkM3u8, playerProvider);
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: StatefulBuilder(
                        builder: (context, setStateItem) {
                          final bool isFocused = focusNode.hasFocus;

                          if (isFocused &&
                              _episodesScrollController.hasClients) {
                            final double itemOffset = index * 64.0;
                            final double currentScroll =
                                _episodesScrollController.offset;
                            final double viewportHeight =
                                _episodesScrollController
                                    .position.viewportDimension;

                            if (itemOffset < currentScroll) {
                              _episodesScrollController.animateTo(
                                itemOffset,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeInOut,
                              );
                            } else if (itemOffset + 64.0 >
                                currentScroll + viewportHeight) {
                              _episodesScrollController.animateTo(
                                itemOffset - viewportHeight + 64.0,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeInOut,
                              );
                            }
                          }

                          return InkWell(
                            onFocusChange: (hasFocus) {
                              setStateItem(() {});
                            },
                            onTap: () {
                              _selectEpisode(
                                  index, episode.linkM3u8, playerProvider);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? const Color(0xFF334155)
                                    : isCurrentPlaying
                                        ? Colors.white12
                                        : Colors.black26,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused
                                      ? Colors.white
                                      : isCurrentPlaying
                                          ? Colors.amber
                                          : Colors.white12,
                                  width: isFocused ? 2.0 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      widget.movieModel.horizontalPhoto,
                                      width: 70,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 70,
                                          height: 42,
                                          color: Colors.white10,
                                          child: const Icon(Icons.movie,
                                              color: Colors.white38),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      episode.name.isNotEmpty
                                          ? episode.name
                                          : "Tập ${index + 1}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isFocused
                                            ? Colors.white
                                            : isCurrentPlaying
                                                ? Colors.amber
                                                : Colors.white70,
                                        fontSize: 14,
                                        fontWeight:
                                            isFocused || isCurrentPlaying
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentPlaying)
                                    const Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectEpisode(
      int index, String newUrl, PlayerProvider playerProvider) async {
    if (newUrl.isEmpty || playerProvider.changingVideo) return;

    setState(() {
      _currentEpisodeIndex = index;
    });

    _saveProgress(playerProvider);
    await playerProvider.changeVideo(newUrl);
    _closeEpisodeList(playerProvider);
  }

  void _saveProgress(PlayerProvider playerProvider) {
    try {
      final controller = playerProvider.videoPlayerController;
      if (controller != null && controller.value.isInitialized) {
        final position = controller.value.position.inSeconds.toDouble();
        final duration = controller.value.duration.inSeconds.toDouble();

        MovieStorageService.saveWatchProgress(
          movie: widget.movieModel,
          episodeIndex: _currentEpisodeIndex,
          positionSeconds: position,
          durationSeconds: duration,
        );
      }
    } catch (e) {
      debugPrint('Lỗi lưu tiến trình xem phim: $e');
    }
  }

  void _leavePlayer(BuildContext context, PlayerProvider playerProvider) {
    if (_isLeaving) return;
    _isLeaving = true;

    _saveProgress(playerProvider);

    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);
    final String lastFocus = buttonFocusProvider.lastButtonFocusedLabel;

    if (lastFocus.isNotEmpty && !lastFocus.contains('_')) {
      buttonFocusProvider.buttonFocusedLabel = lastFocus;
    } else {
      buttonFocusProvider.buttonFocusedLabel = "home_play_icon";
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
