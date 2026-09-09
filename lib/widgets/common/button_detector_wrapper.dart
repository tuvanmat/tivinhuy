import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ButtonDetectorWrapper extends StatefulWidget {
  final Widget child;
  final bool hasFocus;

  final VoidCallback? onLeftPressed;
  final VoidCallback? onRightPressed;
  final VoidCallback? onTopPressed;
  final VoidCallback? onBottomPressed;
  final VoidCallback? onEnterPressed;

  const ButtonDetectorWrapper({
    super.key,
    required this.child,
    required this.hasFocus,
    this.onLeftPressed,
    this.onRightPressed,
    this.onTopPressed,
    this.onBottomPressed,
    this.onEnterPressed,
  });

  @override
  State<ButtonDetectorWrapper> createState() => _ButtonDetectorWrapperState();
}

class _ButtonDetectorWrapperState extends State<ButtonDetectorWrapper> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ButtonDetectorWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.hasFocus != widget.hasFocus) {
      if (widget.hasFocus) {
        _focusNode.requestFocus();
      } else {
        // Chủ động nhả focus khi mất trạng thái chọn để tránh kẹt phím ngầm
        _focusNode.unfocus();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.hasFocus) return KeyEventResult.ignored;

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onLeftPressed?.call();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onRightPressed?.call();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onTopPressed?.call();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onBottomPressed?.call();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.numpadEnter)) {
      widget.onEnterPressed?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
