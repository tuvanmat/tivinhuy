import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/widgets/common/button_detector_wrapper.dart';
import 'package:tv_flutter_app/widgets/common/custom_icon_button.dart';

class FocusableIcon extends StatelessWidget {
  final String path;

  final bool outlined;
  final double size;
  final double backgroundOpacity;
  final String label;

  final String? leftLabel;
  final String? rightLabel;
  final String? topLabel;
  final String? bottomLabel;

  final VoidCallback? onLeftPressed;
  final VoidCallback? onTopPressed;
  final VoidCallback? onBottomPressed;
  final VoidCallback? onRightPressed;
  final VoidCallback? onEnterPressed;

  const FocusableIcon({
    super.key,
    required this.path,
    this.outlined = false,
    this.size = 4,
    this.backgroundOpacity = 0.3,
    this.label = "",
    this.leftLabel,
    this.rightLabel,
    this.topLabel,
    this.bottomLabel,
    this.onLeftPressed,
    this.onTopPressed,
    this.onBottomPressed,
    this.onRightPressed,
    this.onEnterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ButtonFocusProvider, String>(
      selector: (context, buttonFocusProvider) =>
          buttonFocusProvider.buttonFocusedLabel,
      builder: (context, buttonFocusedLabel, _) {
        final bool focused = buttonFocusedLabel == label;

        final buttonFocusProvider = Provider.of<ButtonFocusProvider>(
          context,
          listen: false,
        );

        // ============================================================
        // CHUYỂN FOCUS SANG TRÁI
        // ============================================================

        void moveLeft() {
          if (leftLabel == null || leftLabel!.isEmpty) {
            return;
          }

          buttonFocusProvider.buttonFocusedLabel = leftLabel!;
          onLeftPressed?.call();
        }

        // ============================================================
        // CHUYỂN FOCUS SANG PHẢI
        // ============================================================

        void moveRight() {
          if (rightLabel == null || rightLabel!.isEmpty) {
            return;
          }

          buttonFocusProvider.buttonFocusedLabel = rightLabel!;
          onRightPressed?.call();
        }

        // ============================================================
        // CHUYỂN FOCUS LÊN
        // ============================================================

        void moveTop() {
          if (topLabel == null || topLabel!.isEmpty) {
            return;
          }

          buttonFocusProvider.buttonFocusedLabel = topLabel!;
          onTopPressed?.call();
        }

        // ============================================================
        // CHUYỂN FOCUS XUỐNG
        // ============================================================

        void moveBottom() {
          if (bottomLabel == null || bottomLabel!.isEmpty) {
            return;
          }

          buttonFocusProvider.buttonFocusedLabel = bottomLabel!;
          onBottomPressed?.call();
        }

        return ButtonDetectorWrapper(
          hasFocus: focused,
          onLeftPressed: moveLeft,
          onRightPressed: moveRight,
          onTopPressed: moveTop,
          onBottomPressed: moveBottom,
          onEnterPressed: onEnterPressed,
          child: AnimatedScale(
            scale: focused ? 1.10 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: CustomIconButton(
              size: size,
              fillColor: focused
                  ? Colors.white
                  : Colors.black.withValues(
                      alpha: backgroundOpacity,
                    ),
              onPressed: () {
                onEnterPressed?.call();
              },
              iconPer: 0.4,
              borderColor: focused
                  ? Colors.white
                  : outlined
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.transparent,
              borderWidth: focused
                  ? 2.5
                  : outlined
                      ? 1.0
                      : 0.0,
              borderRadius: outlined ? 5 : 100,
              icon: SvgPicture.asset(
                path,
                color: focused
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      },
    );
  }
}
