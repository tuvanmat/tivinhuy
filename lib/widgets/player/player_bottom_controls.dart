import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/providers/player_provider.dart';
import 'package:tv_flutter_app/widgets/common/v_spacing.dart';
import 'package:video_player/video_player.dart';

class PlayerBottomControls extends StatefulWidget {
  final bool isPlaying;
  final Function() onBack;
  final Function() onForward;
  final Function() onPlay;
  final List<EpisodeModel> episodes;
  final Future<void> Function(String url)? onEpisodeSelected;
  final Future<void> Function()? onPreviousEpisode;
  final Future<void> Function()? onNextEpisode;
  final VoidCallback? onToggleEpisodeList;

  final String movieTitle;
  final String episodeTitle;
  final String quality;

  const PlayerBottomControls({
    super.key,
    required this.isPlaying,
    required this.onBack,
    required this.onForward,
    required this.onPlay,
    this.episodes = const [],
    this.onEpisodeSelected,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onToggleEpisodeList,
    this.movieTitle = '',
    this.episodeTitle = '',
    this.quality = '',
  });

  @override
  State<PlayerBottomControls> createState() => _PlayerBottomControlsState();
}

class _PlayerBottomControlsState extends State<PlayerBottomControls> {
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'PlayButton');
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'BackButton');
  final FocusNode _forwardFocusNode = FocusNode(debugLabel: 'ForwardButton');
  final FocusNode _prevEpFocusNode = FocusNode(debugLabel: 'PrevEpButton');
  final FocusNode _nextEpFocusNode = FocusNode(debugLabel: 'NextEpButton');
  final FocusNode _menuFocusNode = FocusNode(debugLabel: 'MenuButton');

  @override
  void initState() {
    super.initState();
    _requestFocus();
  }

  @override
  void didUpdateWidget(covariant PlayerBottomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeTitle != widget.episodeTitle ||
        oldWidget.isPlaying != widget.isPlaying) {
      _requestFocus();
    }
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _playFocusNode.dispose();
    _backFocusNode.dispose();
    _forwardFocusNode.dispose();
    _prevEpFocusNode.dispose();
    _nextEpFocusNode.dispose();
    _menuFocusNode.dispose();
    super.dispose();
  }

  Widget _buildButton({
    required FocusNode focusNode,
    required String assetPath,
    required VoidCallback onPressed,
    double size = 24,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFocused ? Colors.amber : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: SvgPicture.asset(
                assetPath,
                width: size,
                height: size,
                color: isFocused ? Colors.black : Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        if (!provider.videoPlayerInitialized ||
            provider.videoPlayerController == null) {
          return const SizedBox.shrink();
        }

        final bool isSeries = widget.episodes.length > 1;
        String displayQuality =
            widget.quality.isNotEmpty ? widget.quality.toUpperCase() : "HD";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. TIÊU ĐỀ PHIM & CHẤT LƯỢNG
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movieTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.episodeTitle.isNotEmpty)
                        Text(
                          widget.episodeTitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayQuality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          "HD",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. THANH TIẾN TRÌNH & CỤM NÚT ĐIỀU KHIỂN
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        provider.nowTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: VideoProgressIndicator(
                            provider.videoPlayerController!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.redAccent,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        provider.totalTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const VSpacing(3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: FocusScope(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // NÚT TẬP TRƯỚC
                          if (isSeries) ...[
                            _buildButton(
                              focusNode: _prevEpFocusNode,
                              assetPath: "assets/icons/arrow-back-icon.svg",
                              onPressed: () async {
                                if (playerProvider.changingVideo) return;
                                await widget.onPreviousEpisode?.call();
                              },
                            ),
                            const SizedBox(width: 12),
                          ],

                          // NÚT TUA LẠI
                          _buildButton(
                            focusNode: _backFocusNode,
                            assetPath: "assets/icons/double-left.svg",
                            onPressed: widget.onBack,
                          ),

                          const SizedBox(width: 12),

                          // NÚT PLAY / PAUSE
                          _buildButton(
                            focusNode: _playFocusNode,
                            assetPath: widget.isPlaying
                                ? "assets/icons/pause-icon.svg"
                                : "assets/icons/play-icon.svg",
                            size: 32,
                            onPressed: widget.onPlay,
                          ),

                          const SizedBox(width: 12),

                          // NÚT TUA TỚI
                          _buildButton(
                            focusNode: _forwardFocusNode,
                            assetPath: "assets/icons/double-right.svg",
                            onPressed: widget.onForward,
                          ),

                          // NÚT TẬP SAU
                          if (isSeries) ...[
                            const SizedBox(width: 12),
                            _buildButton(
                              focusNode: _nextEpFocusNode,
                              assetPath: "assets/icons/arrow-forward-icon.svg",
                              onPressed: () async {
                                if (playerProvider.changingVideo) return;
                                await widget.onNextEpisode?.call();
                              },
                            ),
                          ],

                          // NÚT DANH SÁCH TẬP
                          if (isSeries) ...[
                            const SizedBox(width: 12),
                            _buildButton(
                              focusNode: _menuFocusNode,
                              assetPath: "assets/icons/menu-icon.svg",
                              onPressed: () {
                                widget.onToggleEpisodeList?.call();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
