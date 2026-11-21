import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/providers/player_provider.dart';
import 'package:video_player/video_player.dart';

class CustomVideoPlayer extends StatelessWidget {
  final String videoUrl;

  const CustomVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (videoUrl.isEmpty) {
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
        if (!playerProvider.videoPlayerInitialized) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (playerProvider.videoPlayerDisposed) {
          return const SizedBox.expand();
        }

        final VideoPlayerController? controller =
            playerProvider.videoPlayerController;

        if (controller == null || !controller.value.isInitialized) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

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
