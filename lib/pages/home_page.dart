import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/labels.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:tv_flutter_app/widgets/common/sidebar.dart';
import 'package:tv_flutter_app/widgets/home/home_background.dart';
import 'package:tv_flutter_app/widgets/home/home_gradient.dart';
import 'package:tv_flutter_app/widgets/home/movies_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarExpanded = false;
  bool _isHoveringSidebar = false;
  final FocusNode _homeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreHomeFocus();
    });
  }

  @override
  void dispose() {
    _homeFocusNode.dispose();
    super.dispose();
  }

  void _restoreHomeFocus() {
    if (!mounted) return;

    final focusProvider = Provider.of<ButtonFocusProvider>(
      context,
      listen: false,
    );

    final currentFocus = focusProvider.buttonFocusedLabel;
    if (currentFocus == "home_play_icon" || currentFocus.isEmpty) {
      focusProvider.buttonFocusedLabel = "${topMoviesItem}0";
      focusProvider.lastButtonFocusedLabel = "${topMoviesItem}0";
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreHomeFocus();
        });
      },
      child: Scaffold(
        body: Focus(
          focusNode: _homeFocusNode,
          child: Selector<ButtonFocusProvider, String>(
            selector: (context, provider) => provider.buttonFocusedLabel,
            builder: (context, buttonFocusedLabel, _) {
              final bool isRemoteInSidebar =
                  buttonFocusedLabel.startsWith("sidebar_");

              final bool shouldExpand = isRemoteInSidebar || _isHoveringSidebar;

              if (_isSidebarExpanded != shouldExpand) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isSidebarExpanded = shouldExpand;
                    });
                  }
                });
              }

              return Row(
                children: [
                  MouseRegion(
                    onEnter: (_) {
                      setState(() {
                        _isHoveringSidebar = true;
                        _isSidebarExpanded = true;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        _isHoveringSidebar = false;
                        if (!isRemoteInSidebar) {
                          _isSidebarExpanded = false;
                        }
                      });
                    },
                    child: Sidebar(
                      isExpanded: _isSidebarExpanded,
                      onHoverOrFocus: (expanded) {
                        if (_isSidebarExpanded != expanded) {
                          setState(() {
                            _isSidebarExpanded = expanded;
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) {
                        setState(() {
                          _isHoveringSidebar = false;
                          if (!isRemoteInSidebar) {
                            _isSidebarExpanded = false;
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          const HomeBackground(),
                          const HomeGradient(),
                          Container(
                            height: mqHeigth(context, 100),
                            padding: EdgeInsets.symmetric(
                              horizontal: mqWidth(context, 1.5),
                              vertical: mqHeigth(context, 2),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: MoviesList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
