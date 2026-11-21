import 'package:flutter/material.dart';
import 'package:tv_flutter_app/widgets/common/logo_loader.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/utils/app_colors.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/providers/player_provider.dart';
import 'package:tv_flutter_app/services/license_service.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/player/custom_video_player.dart';
import 'package:tv_flutter_app/widgets/player/player_gradient.dart';

class ChannelPlaybackItem {
  final String name;
  final String logo;
  final String url;
  final List<String> urls;

  ChannelPlaybackItem(
      {required this.name,
      required this.logo,
      required this.url,
      this.urls = const []});

  /// Toàn bộ nguồn phát của kênh (chính + dự phòng), không rỗng.
  List<String> get allUrls => urls.isNotEmpty ? urls : [url];
}

class PlayerPage extends StatefulWidget {
  final MovieModel movieModel;
  final int initialEpisodeIndex;
  final double initialPositionSeconds;

  final List<ChannelPlaybackItem>? channelList;
  final int currentChannelIndex;

  const PlayerPage({
    super.key,
    required this.movieModel,
    this.initialEpisodeIndex = 0,
    this.initialPositionSeconds = 0.0,
    this.channelList,
    this.currentChannelIndex = 0,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _isLeaving = false;
  bool _isCheckingLicense = true;
  bool _isAuthorized = false;

  bool _hasStreamError = false;

  late int _activeChannelIndex;
  late MovieModel _currentMovieModel;

  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _backButtonFocusNode =
      FocusNode(debugLabel: 'PlayerBackButtonFocus');

  @override
  void initState() {
    super.initState();
    _activeChannelIndex = widget.currentChannelIndex;
    _currentMovieModel = widget.movieModel;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      _showLicenseErrorDialog();
    }
  }

  void _showLicenseErrorDialog() {
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
          'Không thể phát kênh. Hết thời gian dùng thử hoặc chưa kích hoạt bản quyền.\n\nHãy quay ra trang chủ, vào trang INFO để xem mã Tivi và nhập mã kích hoạt.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
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

  String _cleanChannelName(String rawName) {
    String cleaned = rawName
        .replaceAll(
            RegExp(r'\b(HD|FHD|SD|4K|1080P|720P|576P|480P)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]\s*'), ' ')
        .trim();
    return cleaned.isEmpty ? rawName : cleaned;
  }

  ChannelPlaybackItem? get _prevChannelItem {
    if (widget.channelList == null || widget.channelList!.isEmpty) return null;
    int prevIdx = (_activeChannelIndex - 1) % widget.channelList!.length;
    if (prevIdx < 0) prevIdx = widget.channelList!.length - 1;
    return widget.channelList![prevIdx];
  }

  ChannelPlaybackItem? get _nextChannelItem {
    if (widget.channelList == null || widget.channelList!.isEmpty) return null;
    int nextIdx = (_activeChannelIndex + 1) % widget.channelList!.length;
    return widget.channelList![nextIdx];
  }

  void _switchChannel(int direction, PlayerProvider provider) {
    if (widget.channelList == null || widget.channelList!.isEmpty) return;

    setState(() {
      _activeChannelIndex =
          (_activeChannelIndex + direction) % widget.channelList!.length;
      if (_activeChannelIndex < 0) {
        _activeChannelIndex = widget.channelList!.length - 1;
      }

      final newChannel = widget.channelList![_activeChannelIndex];
      _currentMovieModel = MovieModel(
        id: 1,
        title: newChannel.name,
        slug: newChannel.name,
        horizontalPhoto: "",
        verticalPhoto: "",
        description: "Truyền hình trực tuyến",
        url: newChannel.url,
        quality: "HD",
        time: "Live",
        language: "Tiếng Việt",
        year: DateTime.now().year.toString(),
        currentEpisode: "Trực tiếp",
        category: "Truyền hình",
        country: "Việt Nam",
        episodes: [],
      );
      _hasStreamError = false;
    });

    provider.changeVideo(_currentMovieModel.url,
        fallbackUrls: widget.channelList![_activeChannelIndex].allUrls);
  }

  @override
  void dispose() {
    _playerFocusNode.dispose();
    _backButtonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLicense) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: LogoLoader(),
        ),
      );
    }

    if (!_isAuthorized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final provider = PlayerProvider();
        provider.onHideControls = () {
          if (mounted) {
            _playerFocusNode.requestFocus();
          }
        };

        provider.onError = () {
          if (mounted) {
            setState(() {
              _hasStreamError = true;
            });
          }
        };

        final targetUrl = _currentMovieModel.url;
        final items = widget.channelList;
        final List<String> fallbacks = (items != null &&
                _activeChannelIndex >= 0 &&
                _activeChannelIndex < items.length)
            ? items[_activeChannelIndex].allUrls
            : const [];
        provider.init(targetUrl,
            initialPositionSeconds: 0.0, fallbackUrls: fallbacks);

        return provider;
      },
      child: Builder(
        builder: (context) {
          final playerProvider =
              Provider.of<PlayerProvider>(context, listen: false);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _leavePlayer(context, playerProvider);
            },
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Focus(
                focusNode: _playerFocusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _switchChannel(-1, playerProvider);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _switchChannel(1, playerProvider);
                      return KeyEventResult.handled;
                    }

                    if (!playerProvider.controlsVisible) {
                      playerProvider.activeControls();
                      _playerFocusNode.requestFocus();
                    } else {
                      playerProvider.activeControls();
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (_backButtonFocusNode.canRequestFocus) {
                          _backButtonFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onTap: () {
                    if (playerProvider.controlsVisible) {
                      setState(() {
                        playerProvider.controlsVisible = false;
                      });
                    } else {
                      playerProvider.activeControls();
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! > 300) {
                        _switchChannel(-1, playerProvider);
                      } else if (details.primaryVelocity! < -300) {
                        _switchChannel(1, playerProvider);
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      SizedBox(
                        width: mqWidth(context, 100),
                        height: mqHeigth(context, 100),
                        child: Image.network(
                          _currentMovieModel.horizontalPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.black);
                          },
                        ),
                      ),
                      CustomVideoPlayer(
                        videoUrl: _currentMovieModel.url,
                      ),
                      Consumer<PlayerProvider>(
                        builder: (context, provider, _) {
                          if (provider.videoPlayerDisposed) {
                            return const SizedBox.shrink();
                          }

                          final bool showControls = provider.controlsVisible;
                          final prevItem = _prevChannelItem;
                          final nextItem = _nextChannelItem;

                          return Stack(
                            children: [
                              if (showControls) const PlayerGradient(),

                              // Nút Back rõ ràng ở góc trên bên trái
                              if (showControls)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Focus(
                                    focusNode: _backButtonFocusNode,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.select ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.enter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.space) {
                                          _leavePlayer(context, provider);
                                          return KeyEventResult.handled;
                                        }
                                        if (event.logicalKey ==
                                                LogicalKeyboardKey.arrowDown ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.arrowRight) {
                                          _playerFocusNode.requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: AnimatedBuilder(
                                      animation: _backButtonFocusNode,
                                      builder: (context, child) {
                                        final isFocused =
                                            _backButtonFocusNode.hasFocus;
                                        return InkWell(
                                          onTap: () =>
                                              _leavePlayer(context, provider),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: isFocused
                                                  ? AppColors.brandBright
                                                  : Colors.white
                                                      .withValues(alpha: 0.35),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: isFocused ? 2.5 : 1.8,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black45,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.arrow_back,
                                              color: isFocused
                                                  ? Colors.black
                                                  : Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                              // CẢNH BÁO LỖI NẰM Ở GIỮA PHÍA TRÊN
                              if (showControls && _hasStreamError)
                                Positioned(
                                  top: 100,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black54,
                                            blurRadius: 10,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              color: Colors.white, size: 22),
                                          SizedBox(width: 8),
                                          Text(
                                            '⚠️ Kênh đang gián đoạn (Vuốt Trái/Phải để đổi kênh)',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                              // NÚT TRÁI & PHẢI SÁT MÉP 2 BÊN
                              if (showControls &&
                                  widget.channelList != null &&
                                  widget.channelList!.isNotEmpty) ...[
                                // Nút Kênh Trước (Sát mép TRÁI)
                                Positioned(
                                  left: 25,
                                  top: MediaQuery.of(context).size.height / 2 -
                                      45,
                                  child: InkWell(
                                    onTap: () => _switchChannel(-1, provider),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.white30, width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.chevron_left,
                                              color: Colors.white, size: 28),
                                          const SizedBox(width: 8),
                                          if (prevItem != null)
                                            SizedBox(
                                              width: 90,
                                              height: 36,
                                              child: Center(
                                                child: prevItem.logo.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: prevItem.logo,
                                                        fit: BoxFit.contain,
                                                        width: 90,
                                                        height: 36,
                                                        placeholder:
                                                            (context, url) =>
                                                                const Center(
                                                          child: SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Text(
                                                          _cleanChannelName(
                                                              prevItem.name),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      )
                                                    : Text(
                                                        _cleanChannelName(
                                                            prevItem.name),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          decoration:
                                                              TextDecoration
                                                                  .none,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Nút Kênh Sau (Sát mép PHẢI)
                                Positioned(
                                  right: 25,
                                  top: MediaQuery.of(context).size.height / 2 -
                                      45,
                                  child: InkWell(
                                    onTap: () => _switchChannel(1, provider),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.white30, width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (nextItem != null)
                                            SizedBox(
                                              width: 90,
                                              height: 36,
                                              child: Center(
                                                child: nextItem.logo.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: nextItem.logo,
                                                        fit: BoxFit.contain,
                                                        width: 90,
                                                        height: 36,
                                                        placeholder:
                                                            (context, url) =>
                                                                const Center(
                                                          child: SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Text(
                                                          _cleanChannelName(
                                                              nextItem.name),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      )
                                                    : Text(
                                                        _cleanChannelName(
                                                            nextItem.name),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          decoration:
                                                              TextDecoration
                                                                  .none,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.chevron_right,
                                              color: Colors.white, size: 28),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
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

  void _leavePlayer(BuildContext context, PlayerProvider playerProvider) {
    if (_isLeaving) return;
    _isLeaving = true;

    playerProvider.disposeVideoPlayer();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
