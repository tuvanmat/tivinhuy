import 'package:flutter/material.dart';
import 'package:tv_flutter_app/widgets/common/logo_loader.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/pages/player_page.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/services/channel_service.dart';
import 'package:tv_flutter_app/utils/navigation.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/home/home_background.dart';
import 'package:tv_flutter_app/widgets/home/home_gradient.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusNode _homeFocusNode = FocusNode();
  final ScrollController _gridScrollController = ScrollController();

  bool _isLoading = true;
  List<ChannelItem> _vtvChannels = [];
  List<FocusNode> _focusNodes = [];
  final int _crossAxisCount = 4;

  @override
  void initState() {
    super.initState();
    _loadVtvChannels();
  }

  @override
  void dispose() {
    _homeFocusNode.dispose();
    _gridScrollController.dispose();
    _disposeFocusNodes();
    super.dispose();
  }

  void _disposeFocusNodes() {
    for (var node in _focusNodes) {
      node.dispose();
    }
  }

  Future<void> _loadVtvChannels() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final channels = await ChannelService.getChannelsByType('VTV');

      _disposeFocusNodes();

      if (mounted) {
        setState(() {
          _vtvChannels = channels;
          _focusNodes = List.generate(
            _vtvChannels.length,
            (index) => FocusNode(debugLabel: 'vtv_channel_node_$index'),
          );
          _isLoading = false;
        });
      }

      if (_focusNodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focusNodes[0].canRequestFocus) {
            _focusNodes[0].requestFocus();
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi tải kênh VTV: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playChannel(ChannelItem channel, int index) {
    final fakeMovie = MovieModel(
      id: 1,
      title: channel.name,
      slug: channel.name,
      horizontalPhoto: "",
      verticalPhoto: "",
      description: "Truyền hình VTV trực tuyến",
      url: channel.url,
      quality: "HD",
      time: "Live",
      language: "Tiếng Việt",
      year: DateTime.now().year.toString(),
      currentEpisode: "Trực tiếp",
      category: "Truyền hình",
      country: "Việt Nam",
      episodes: [],
    );

    final playbackList = _vtvChannels
        .map((e) => ChannelPlaybackItem(
              name: e.name,
              logo: e.logo,
              url: e.url,
            ))
        .toList();

    Navigator.push(
      context,
      materialNavigationRoute(
        context,
        PlayerPage(
          movieModel: fakeMovie,
          channelList: playbackList,
          currentChannelIndex: index,
        ),
      ),
    ).then((_) {
      if (mounted && _focusNodes.isNotEmpty && index < _focusNodes.length) {
        if (_focusNodes[index].canRequestFocus) {
          _focusNodes[index].requestFocus();
          _scrollToIndex(index);
        }
      }
    });
  }

  void _scrollToIndex(int index) {
    if (!_gridScrollController.hasClients) return;
    int row = index ~/ _crossAxisCount;
    double targetOffset = row * 110.0;
    double maxScroll = _gridScrollController.position.maxScrollExtent;
    if (targetOffset > maxScroll) targetOffset = maxScroll;

    _gridScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _homeFocusNode,
        child: Selector<ButtonFocusProvider, String>(
          selector: (context, provider) => provider.buttonFocusedLabel,
          builder: (context, buttonFocusedLabel, _) {
            // SỬA LỖI: Chỉ bắt sự kiện node của trang, loại bỏ nhãn sidebar_home_tvt
            if (buttonFocusedLabel == "vtv_channel_node_0" &&
                _focusNodes.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _focusNodes[0].canRequestFocus) {
                  _focusNodes[0].requestFocus();
                }
              });
            }

            return Stack(
              children: [
                const HomeBackground(),
                const HomeGradient(),
                Container(
                  height: mqHeigth(context, 100),
                  padding: EdgeInsets.symmetric(
                    horizontal: mqWidth(context, 2),
                    vertical: mqHeigth(context, 2),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: LogoLoader(),
                        )
                      : _vtvChannels.isEmpty
                          ? const Center(
                              child: Text(
                                'Không tìm thấy kênh VTV nào.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16),
                              ),
                            )
                          : GridView.builder(
                              controller: _gridScrollController,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                              ),
                              itemCount: _vtvChannels.length,
                              itemBuilder: (context, index) {
                                final channel = _vtvChannels[index];
                                final focusNode = _focusNodes[index];
                                final int totalItems = _vtvChannels.length;

                                return Focus(
                                  focusNode: focusNode,
                                  onFocusChange: (hasFocus) {
                                    if (hasFocus) {
                                      _scrollToIndex(index);
                                    }
                                  },
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent ||
                                        event is KeyRepeatEvent) {
                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowLeft) {
                                        if (index % _crossAxisCount == 0) {
                                          final provider =
                                              Provider.of<ButtonFocusProvider>(
                                                  context,
                                                  listen: false);
                                          provider.buttonFocusedLabel =
                                              "sidebar_home_tvt";
                                          return KeyEventResult.handled;
                                        } else {
                                          _focusNodes[index - 1].requestFocus();
                                          return KeyEventResult.handled;
                                        }
                                      }

                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowRight) {
                                        int nextIndex = index + 1;
                                        if (nextIndex < totalItems) {
                                          _focusNodes[nextIndex].requestFocus();
                                        } else {
                                          _focusNodes[0].requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }

                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowUp) {
                                        int prevRowIndex =
                                            index - _crossAxisCount;
                                        if (prevRowIndex < 0) {
                                          int col = index % _crossAxisCount;
                                          int lastRowStart =
                                              ((totalItems - 1) ~/
                                                      _crossAxisCount) *
                                                  _crossAxisCount;
                                          int targetIndex = lastRowStart + col;
                                          if (targetIndex >= totalItems) {
                                            targetIndex = totalItems - 1;
                                          }
                                          _focusNodes[targetIndex]
                                              .requestFocus();
                                        } else {
                                          _focusNodes[prevRowIndex]
                                              .requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }

                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowDown) {
                                        int nextRowIndex =
                                            index + _crossAxisCount;
                                        if (nextRowIndex >= totalItems) {
                                          int col = index % _crossAxisCount;
                                          _focusNodes[0].requestFocus();
                                        } else {
                                          _focusNodes[nextRowIndex]
                                              .requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }

                                      if (event.logicalKey ==
                                              LogicalKeyboardKey.select ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.enter ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.space ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.gameButtonA) {
                                        _playChannel(channel, index);
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      final bool hasFocus =
                                          Focus.of(context).hasFocus;
                                      return InkWell(
                                        onTap: () =>
                                            _playChannel(channel, index),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: hasFocus
                                                ? Colors.amber
                                                : const Color(0xFF1E2430),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: hasFocus
                                                  ? Colors.white
                                                  : Colors.white24,
                                              width: hasFocus ? 2.5 : 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: channel.logo.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: channel.logo,
                                                      fit: BoxFit.contain,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      placeholder:
                                                          (context, url) =>
                                                              Center(
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: hasFocus
                                                                ? Colors.black
                                                                : Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          _buildFallbackText(
                                                              channel.name,
                                                              hasFocus),
                                                    )
                                                  : _buildFallbackText(
                                                      channel.name, hasFocus),
                                            ),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackText(String name, bool hasFocus) {
    return Center(
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: hasFocus ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
