import 'package:flutter/material.dart';

/// Màn hình chờ tải dùng logo của app với vệt sáng chạy qua,
/// thay cho vòng xoay mặc định.
class LogoLoader extends StatefulWidget {
  final double width;
  final bool showMessage;

  const LogoLoader({super.key, this.width = 220, this.showMessage = true});

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) {
                  final dx = bounds.width * (2.4 * _controller.value - 0.7);
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: const [
                      Colors.transparent,
                      Colors.white54,
                      Colors.transparent,
                    ],
                    stops: const [0.35, 0.5, 0.65],
                    transform: _SlideGradientTransform(dx),
                  ).createShader(bounds);
                },
                child: child,
              );
            },
            child: Image.asset(
              'assets/images/logo_banner.png',
              width: widget.width,
              fit: BoxFit.contain,
            ),
          ),
          if (widget.showMessage) ...[
            const SizedBox(height: 16),
            const Text(
              'Đang tải...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double dx;
  const _SlideGradientTransform(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}
