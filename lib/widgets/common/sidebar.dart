import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tv_flutter_app/services/license_service.dart';
import 'package:tv_flutter_app/widgets/common/v_spacing.dart';

class Sidebar extends StatefulWidget {
  final bool isExpanded;
  final Function(bool) onHoverOrFocus;
  final VoidCallback? onVtvHomeSelected;
  final Function(int)? onTabSelected;

  const Sidebar({
    super.key,
    required this.isExpanded,
    required this.onHoverOrFocus,
    this.onVtvHomeSelected,
    this.onTabSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final List<String> _sidebarOrder = [
    "sidebar_home_tvt",
    "sidebar_sctv",
    "sidebar_htv",
    "sidebar_local",
    "sidebar_info",
  ];

    String _version = '';
  Color _dotColor = const Color(0xFF83838E);
late final Map<String, FocusNode> _focusNodes = {
    "sidebar_home_tvt": FocusNode(debugLabel: 'sidebar_home_tvt'),
    "sidebar_sctv": FocusNode(debugLabel: 'sidebar_sctv'),
    "sidebar_htv": FocusNode(debugLabel: 'sidebar_htv'),
    "sidebar_local": FocusNode(debugLabel: 'sidebar_local'),
    "sidebar_info": FocusNode(debugLabel: 'sidebar_info'),
  };

  
  @override
  void initState() {
    super.initState();
    _loadFooterInfo();
  }

  Future<void> _loadFooterInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
    final data = await LicenseService.fetchLicenseStatus();
    if (mounted && data != null) {
      final st = data['status'];
      setState(() {
        _dotColor = st == 'active'
            ? const Color(0xFF3ECF6A)
            : (st == 'trial'
                ? const Color(0xFFFBBF24)
                : const Color(0xFFF87171));
      });
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            provider.buttonFocusedLabel = "sidebar_home_tvt";
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
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                    horizontal: widget.isExpanded ? 10 : 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebarItem(
                      context,
                      path: "assets/icons/home-icon.svg",
                      label: "VTV",
                      targetLabel: "sidebar_home_tvt",
                      onEnter: () {
                        widget.onHoverOrFocus(false);
                        if (widget.onTabSelected != null) {
                          widget.onTabSelected!(0);
                        }
                        if (widget.onVtvHomeSelected != null) {
                          widget.onVtvHomeSelected!();
                        }
                        Provider.of<ButtonFocusProvider>(context, listen: false)
                            .buttonFocusedLabel = "vtv_channel_node_0";
                      },
                    ),
                    const VSpacing(2),
                    _buildSidebarItem(
                      context,
                      path: "assets/icons/play-icon.svg",
                      label: "SCTV",
                      targetLabel: "sidebar_sctv",
                      onEnter: () {
                        widget.onHoverOrFocus(false);
                        if (widget.onTabSelected != null) {
                          widget.onTabSelected!(1);
                        }
                        Provider.of<ButtonFocusProvider>(context, listen: false)
                            .buttonFocusedLabel = "sctv_channel_node_0";
                      },
                    ),
                    const VSpacing(2),
                    _buildSidebarItem(
                      context,
                      path: "assets/icons/play-icon.svg",
                      label: "HTV",
                      targetLabel: "sidebar_htv",
                      onEnter: () {
                        widget.onHoverOrFocus(false);
                        if (widget.onTabSelected != null) {
                          widget.onTabSelected!(2);
                        }
                        Provider.of<ButtonFocusProvider>(context, listen: false)
                            .buttonFocusedLabel = "htv_channel_node_0";
                      },
                    ),
                    const VSpacing(2),
                    _buildSidebarItem(
                      context,
                      path: "assets/icons/play-icon.svg",
                      label: "Địa phương",
                      targetLabel: "sidebar_local",
                      onEnter: () {
                        widget.onHoverOrFocus(false);
                        if (widget.onTabSelected != null) {
                          widget.onTabSelected!(3);
                        }
                        Provider.of<ButtonFocusProvider>(context, listen: false)
                            .buttonFocusedLabel = "local_channel_node_0";
                      },
                    ),
                    const VSpacing(2),
                    _buildSidebarItem(
                      context,
                      path: "assets/icons/info-icon.svg",
                      label: "Thông tin",
                      targetLabel: "sidebar_info",
                      onEnter: () {
                        widget.onHoverOrFocus(false);
                        if (widget.onTabSelected != null) {
                          widget.onTabSelected!(4);
                        }
                        Provider.of<ButtonFocusProvider>(context, listen: false)
                            .buttonFocusedLabel = "info_page_focus";
                      },
                    ),
                                      const VSpacing(3),
                    if (widget.isExpanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 10, top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _version.isEmpty ? 'V ...' : 'V $_version',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),],
                ),
              ),
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
            Provider.of<ButtonFocusProvider>(context, listen: false)
                .buttonFocusedLabel = targetLabel;
            widget.onHoverOrFocus(true);
            if (widget.onTabSelected != null) {
              if (targetLabel == "sidebar_home_tvt") {
                widget.onTabSelected!(0);
              } else if (targetLabel == "sidebar_sctv")
                widget.onTabSelected!(1);
              else if (targetLabel == "sidebar_htv")
                widget.onTabSelected!(2);
              else if (targetLabel == "sidebar_local")
                widget.onTabSelected!(3);
              else if (targetLabel == "sidebar_info") widget.onTabSelected!(4);
            }
          },
          child: Focus(
            focusNode: node,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                widget.onHoverOrFocus(true);
                Provider.of<ButtonFocusProvider>(context, listen: false)
                    .buttonFocusedLabel = targetLabel;

                if (widget.onTabSelected != null) {
                  if (targetLabel == "sidebar_home_tvt") {
                    widget.onTabSelected!(0);
                  } else if (targetLabel == "sidebar_sctv")
                    widget.onTabSelected!(1);
                  else if (targetLabel == "sidebar_htv")
                    widget.onTabSelected!(2);
                  else if (targetLabel == "sidebar_local")
                    widget.onTabSelected!(3);
                  else if (targetLabel == "sidebar_info")
                    widget.onTabSelected!(4);
                }
              }
            },
            onKeyEvent: (nodeElement, event) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  widget.onHoverOrFocus(false);
                  final buttonFocusProvider =
                      Provider.of<ButtonFocusProvider>(context, listen: false);
                  if (targetLabel == "sidebar_home_tvt") {
                    if (widget.onTabSelected != null) widget.onTabSelected!(0);
                    buttonFocusProvider.buttonFocusedLabel =
                        "vtv_channel_node_0";
                  } else if (targetLabel == "sidebar_sctv") {
                    if (widget.onTabSelected != null) widget.onTabSelected!(1);
                    buttonFocusProvider.buttonFocusedLabel =
                        "sctv_channel_node_0";
                  } else if (targetLabel == "sidebar_htv") {
                    if (widget.onTabSelected != null) widget.onTabSelected!(2);
                    buttonFocusProvider.buttonFocusedLabel =
                        "htv_channel_node_0";
                  } else if (targetLabel == "sidebar_local") {
                    if (widget.onTabSelected != null) widget.onTabSelected!(3);
                    buttonFocusProvider.buttonFocusedLabel =
                        "local_channel_node_0";
                  } else if (targetLabel == "sidebar_info") {
                    if (widget.onTabSelected != null) widget.onTabSelected!(4);
                    buttonFocusProvider.buttonFocusedLabel = "info_page_focus";
                  }
                  return KeyEventResult.handled;
                }

                if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  final buttonFocusProvider =
                      Provider.of<ButtonFocusProvider>(context, listen: false);

                  int currentIndex = _sidebarOrder.indexOf(targetLabel);
                  if (currentIndex != -1) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      currentIndex = (currentIndex + 1) % _sidebarOrder.length;
                    } else {
                      currentIndex = (currentIndex - 1 + _sidebarOrder.length) %
                          _sidebarOrder.length;
                    }

                    String nextLabel = _sidebarOrder[currentIndex];
                    buttonFocusProvider.buttonFocusedLabel = nextLabel;
                    _focusNodes[nextLabel]?.requestFocus();
                    return KeyEventResult.handled;
                  }
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
              onTap: () {
                if (!widget.isExpanded || !isFocused) {
                  widget.onHoverOrFocus(true);
                  Provider.of<ButtonFocusProvider>(context, listen: false)
                      .buttonFocusedLabel = targetLabel;
                  node.requestFocus();
                } else {
                  onEnter();
                }
              },
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: widget.isExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
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
                        Text(
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
                      ],
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
