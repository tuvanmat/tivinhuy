import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/pages/favorites_page.dart';
import 'package:tv_flutter_app/pages/continue_watching_page.dart';
import 'package:tv_flutter_app/pages/search_page.dart';
import 'package:tv_flutter_app/pages/category_page.dart';
import 'package:tv_flutter_app/pages/info_page.dart';
import 'package:tv_flutter_app/providers/movies_provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/common/v_spacing.dart';

class Sidebar extends StatefulWidget {
  final bool isExpanded;
  final Function(bool) onHoverOrFocus;

  const Sidebar({
    super.key,
    required this.isExpanded,
    required this.onHoverOrFocus,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  // Khởi tạo các FocusNode quản lý riêng từng mục trên Sidebar (Đã thêm sidebar_continue_watching)
  final Map<String, FocusNode> _focusNodes = {
    "sidebar_search": FocusNode(),
    sidebarHomeOption: FocusNode(),
    "sidebar_phim_le": FocusNode(),
    "sidebar_phim_bo": FocusNode(),
    "sidebar_the_loai": FocusNode(),
    "sidebar_quoc_gia": FocusNode(),
    "sidebar_favorites": FocusNode(),
    "sidebar_continue_watching": FocusNode(),
    "sidebar_info": FocusNode(),
  };

  @override
  void dispose() {
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe sự thay đổi focus label từ bên ngoài
    return Selector<ButtonFocusProvider, String>(
      selector: (context, provider) => provider.buttonFocusedLabel,
      builder: (context, focusedLabel, child) {
        if (_focusNodes.containsKey(focusedLabel)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _focusNodes[focusedLabel]!.canRequestFocus) {
              _focusNodes[focusedLabel]!.requestFocus();
            }
          });
        }
        return child!;
      },
      child: MouseRegion(
        onEnter: (_) {
          widget.onHoverOrFocus(true);
          final provider =
              Provider.of<ButtonFocusProvider>(context, listen: false);
          if (!provider.buttonFocusedLabel.startsWith("sidebar_")) {
            provider.buttonFocusedLabel = sidebarHomeOption;
          }
        },
        onExit: (_) => widget.onHoverOrFocus(false),
        child: Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus && !widget.isExpanded) {
              widget.onHoverOrFocus(true);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: mqWidth(context, widget.isExpanded ? 16 : 5.5),
            height: mqHeigth(context, 100),
            color: Colors.black,
            padding:
                EdgeInsets.symmetric(horizontal: widget.isExpanded ? 10 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VSpacing(3),

                // 1. TÌM KIẾM
                _buildSidebarItem(
                  context,
                  path: "assets/icons/search-icon.svg",
                  label: "Tìm kiếm",
                  targetLabel: "sidebar_search",
                  onEnter: () {
                    final buttonFocusProvider =
                        Provider.of<ButtonFocusProvider>(context,
                            listen: false);
                    buttonFocusProvider.buttonFocusedLabel =
                        "${topMoviesItem}0";

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/search'),
                        builder: (context) => const SearchPage(),
                      ),
                    );
                  },
                ),

                const VSpacing(3),

                // 2. TRANG CHỦ
                _buildSidebarItem(
                  context,
                  path: "assets/icons/home-icon.svg",
                  label: "Trang chủ",
                  targetLabel: sidebarHomeOption,
                  onEnter: () async {
                    final routeName = ModalRoute.of(context)?.settings.name;
                    if (routeName == '/search' ||
                        routeName == '/info' ||
                        routeName == '/favorites' ||
                        routeName == '/continue-watching') {
                      Navigator.pop(context);
                    }

                    final buttonFocusProvider =
                        Provider.of<ButtonFocusProvider>(context,
                            listen: false);
                    buttonFocusProvider.buttonFocusedLabel =
                        "${topMoviesItem}0";
                    buttonFocusProvider.lastButtonFocusedLabel =
                        "${topMoviesItem}0";

                    await Provider.of<MoviesProvider>(context, listen: false)
                        .fetchMovies(type: 'phim-moi');
                  },
                ),

                const VSpacing(2),

                // 3. PHIM LẺ
                _buildSidebarItem(
                  context,
                  path: "assets/icons/play-icon.svg",
                  label: "Phim lẻ",
                  targetLabel: "sidebar_phim_le",
                  onEnter: () async {
                    final routeName = ModalRoute.of(context)?.settings.name;
                    if (routeName == '/search' ||
                        routeName == '/info' ||
                        routeName == '/favorites' ||
                        routeName == '/continue-watching') {
                      Navigator.pop(context);
                    }

                    final buttonFocusProvider =
                        Provider.of<ButtonFocusProvider>(context,
                            listen: false);
                    buttonFocusProvider.buttonFocusedLabel =
                        "${topMoviesItem}0";
                    buttonFocusProvider.lastButtonFocusedLabel =
                        "${topMoviesItem}0";

                    await Provider.of<MoviesProvider>(context, listen: false)
                        .fetchMovies(type: 'phim-le');
                  },
                ),

                const VSpacing(2),

                // 4. PHIM BỘ
                _buildSidebarItem(
                  context,
                  path: "assets/icons/double-right.svg",
                  label: "Phim bộ",
                  targetLabel: "sidebar_phim_bo",
                  onEnter: () async {
                    final routeName = ModalRoute.of(context)?.settings.name;
                    if (routeName == '/search' ||
                        routeName == '/info' ||
                        routeName == '/favorites' ||
                        routeName == '/continue-watching') {
                      Navigator.pop(context);
                    }

                    final buttonFocusProvider =
                        Provider.of<ButtonFocusProvider>(context,
                            listen: false);
                    buttonFocusProvider.buttonFocusedLabel =
                        "${topMoviesItem}0";
                    buttonFocusProvider.lastButtonFocusedLabel =
                        "${topMoviesItem}0";

                    await Provider.of<MoviesProvider>(context, listen: false)
                        .fetchMovies(type: 'phim-bo');
                  },
                ),

                const VSpacing(2),

                // 5. THỂ LOẠI
                _buildSidebarItem(
                  context,
                  path: "assets/icons/the-loai.svg",
                  label: "Thể loại",
                  targetLabel: "sidebar_the_loai",
                  onEnter: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryPage(
                          title: 'Chọn Thể Loại',
                          type: 'the-loai',
                        ),
                      ),
                    );
                  },
                ),

                const VSpacing(2),

                // 6. QUỐC GIA
                _buildSidebarItem(
                  context,
                  path: "assets/icons/quoc-gia.svg",
                  label: "Quốc gia",
                  targetLabel: "sidebar_quoc_gia",
                  onEnter: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoryPage(
                          title: 'Chọn Quốc Gia',
                          type: 'quoc-gia',
                        ),
                      ),
                    );
                  },
                ),

                const VSpacing(2),

                // 7. YÊU THÍCH
                _buildSidebarItem(
                  context,
                  path: "assets/icons/favorite-icon.svg",
                  label: "Yêu thích",
                  targetLabel: "sidebar_favorites",
                  onEnter: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/favorites'),
                        builder: (context) => const FavoritesPage(),
                      ),
                    );
                  },
                ),

                const VSpacing(2),

                // 8. XEM TIẾP (PHIM ĐANG XEM)
                _buildSidebarItem(
                  context,
                  path:
                      "assets/icons/xem-tiep.svg", // Bạn có thể thay bằng icon phù hợp
                  label: "Xem tiếp",
                  targetLabel: "sidebar_continue_watching",
                  onEnter: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings:
                            const RouteSettings(name: '/continue-watching'),
                        builder: (context) => const ContinueWatchingPage(),
                      ),
                    );
                  },
                ),

                const VSpacing(2),

                // 9. THÔNG TIN
                _buildSidebarItem(
                  context,
                  path: "assets/icons/info-icon.svg",
                  label: "Thông tin",
                  targetLabel: "sidebar_info",
                  onEnter: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/info'),
                        builder: (context) => const InfoPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required String path,
    required String label,
    required String targetLabel,
    required VoidCallback onEnter,
  }) {
    final FocusNode node = _focusNodes[targetLabel] ?? FocusNode();

    return Selector<ButtonFocusProvider, String>(
      selector: (context, provider) => provider.buttonFocusedLabel,
      builder: (context, focusedLabel, _) {
        final bool isFocused = focusedLabel == targetLabel;

        return MouseRegion(
          onEnter: (_) {
            final buttonFocusProvider =
                Provider.of<ButtonFocusProvider>(context, listen: false);
            buttonFocusProvider.buttonFocusedLabel = targetLabel;
            widget.onHoverOrFocus(true);
          },
          child: Focus(
            focusNode: node,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                widget.onHoverOrFocus(true);
                final buttonFocusProvider =
                    Provider.of<ButtonFocusProvider>(context, listen: false);
                buttonFocusProvider.buttonFocusedLabel = targetLabel;
              }
            },
            onKeyEvent: (nodeElement, event) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  final buttonFocusProvider =
                      Provider.of<ButtonFocusProvider>(context, listen: false);

                  String targetMovieLabel =
                      buttonFocusProvider.lastButtonFocusedLabel;
                  if (!targetMovieLabel.startsWith(topMoviesItem)) {
                    targetMovieLabel = "${topMoviesItem}0";
                  }

                  buttonFocusProvider.buttonFocusedLabel = targetMovieLabel;
                  widget.onHoverOrFocus(false);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space ||
                    event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                  onEnter();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: InkWell(
              onTap: onEnter,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isExpanded ? 8 : 2,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isFocused ? Colors.white24 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: widget.isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: SvgPicture.asset(
                          path,
                          width: 20,
                          height: 20,
                          color: isFocused ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isFocused ? Colors.white : Colors.white70,
                            fontSize: 14,
                            fontWeight:
                                isFocused ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
