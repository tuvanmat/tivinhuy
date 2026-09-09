import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/providers/player_provider.dart';
import 'package:video_player/video_player.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl; // Sử dụng videoUrl thay vì movieModel

  const CustomVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.videoUrl.isNotEmpty) {
        Provider.of<PlayerProvider>(
          context,
          listen: false,
        ).init(widget.videoUrl); // Init đúng url của tập
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy nguồn phát video cho phim này',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        // Controller đang được khởi tạo
        if (!playerProvider.videoPlayerInitialized) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Player đã bị dispose
        if (playerProvider.videoPlayerDisposed) {
          return const SizedBox.expand();
        }

        // Lấy controller nullable
        final VideoPlayerController? controller =
            playerProvider.videoPlayerController;

        // Chưa có controller
        if (controller == null) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Controller chưa initialize hoàn toàn
        if (!controller.value.isInitialized) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Hiển thị video
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      },
    );
  }
}
