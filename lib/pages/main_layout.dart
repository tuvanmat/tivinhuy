import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/pages/home_page.dart';
import 'package:tv_flutter_app/pages/htv_tv_page.dart'; // <--- Trang HTV
import 'package:tv_flutter_app/pages/info_page.dart';
import 'package:tv_flutter_app/pages/local_tv_page.dart';
import 'package:tv_flutter_app/pages/sctv_tv_page.dart'; // <--- Trang SCTV
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/widgets/common/sidebar.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _isSidebarExpanded = false;
  bool _isHoveringSidebar = false;

  // Thứ tự các trang: 0: Home VTV, 1: SCTV, 2: HTV, 3: Địa phương, 4: Thông tin
  final List<Widget> _pages = const [
    HomePage(),
    SctvTvPage(),
    HtvTvPage(),
    LocalTvPage(),
    InfoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Selector<ButtonFocusProvider, String>(
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
                  onTabSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
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
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
