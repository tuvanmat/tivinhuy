import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tv_flutter_app/utils/constants.dart';
import 'package:tv_flutter_app/utils/utils.dart';
import 'package:video_player/video_player.dart';

class PlayerProvider extends ChangeNotifier {
  bool videoPlayerInitialized = false;
  bool videoPlayerDisposed = false;

  VideoPlayerController? videoPlayerController;

  String nowTime = "00:00";
  String totalTime = "00:00";

  Timer? timer;
  Timer? timerTrackVideo;
  Timer? _seekDebounceTimer;
  Timer? _accelerationResetTimer;

  int _targetSeekMilliseconds = 0;
  int _consecutivePressCount = 0;

  final oneSec = const Duration(seconds: 1);

  bool controlsVisible = true;
  bool isPlaying = false;

  bool _changingVideo = false;
  bool get changingVideo => _changingVideo;

  int _initRequestId = 0;

  VoidCallback? onHideControls;

  @override
  void notifyListeners() {
    if (!videoPlayerDisposed && hasListeners) {
      super.notifyListeners();
    }
  }

  Future<void> init(String url, {double initialPositionSeconds = 0.0}) async {
    if (videoPlayerDisposed) {
      return;
    }

    if (url.trim().isEmpty) {
      return;
    }

    final int requestId = ++_initRequestId;

    videoPlayerInitialized = false;
    isPlaying = false;
    controlsVisible = true;

    notifyListeners();
    _cancelTimers();

    final oldController = videoPlayerController;
    if (oldController != null) {
      try {
        await oldController.pause();
      } catch (_) {}
    }

    if (requestId != _initRequestId || videoPlayerDisposed) {
      return;
    }

    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (_) {}
    }

    if (requestId != _initRequestId || videoPlayerDisposed) {
      return;
    }

    videoPlayerController = null;

    String targetUrl = url.trim();
    if (!targetUrl.startsWith('http')) {
      targetUrl = 'https:$targetUrl';
    }

    debugPrint(
        'Đang tiến hành phát video từ URL: $targetUrl (Mốc tua: $initialPositionSeconds giây)');

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(targetUrl),
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    videoPlayerController = controller;

    try {
      await controller.initialize();

      if (requestId != _initRequestId ||
          videoPlayerDisposed ||
          videoPlayerController != controller) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      await controller.setVolume(1.0);
      videoPlayerInitialized = true;

      totalTime = parseTotalTime(
        controller.value.duration.inMilliseconds.round(),
      );

      nowTime = parseTotalTime(
        controller.value.position.inMilliseconds.round(),
      );

      // Bắt đầu chạy video trước để load buffer stream m3u8
      await controller.play();

      if (requestId != _initRequestId ||
          videoPlayerDisposed ||
          videoPlayerController != controller) {
        return;
      }

      isPlaying = true;
      notifyListeners();

      // Sử dụng cơ chế lắng nghe hoặc lặp kiểm tra nhanh để thực hiện seekTo
      // ngay khi duration và buffer của luồng m3u8 sẵn sàng thực sự.
      if (initialPositionSeconds > 0) {
        _performAccurateSeek(controller, initialPositionSeconds, requestId);
      }

      _startControlsTimer();

      timerTrackVideo = Timer.periodic(
        oneSec,
        (_) {
          checkTimer();
        },
      );
    } catch (e) {
      debugPrint('Lỗi khởi tạo video player với URL $targetUrl: $e');
      if (requestId != _initRequestId) {
        return;
      }

      videoPlayerInitialized = false;
      isPlaying = false;
      notifyListeners();

      try {
        await controller.dispose();
      } catch (_) {}

      if (videoPlayerController == controller) {
        videoPlayerController = null;
      }
    }
  }

  // Hàm phụ trợ hỗ trợ ép tua chính xác cho luồng mạng m3u8
  void _performAccurateSeek(
      VideoPlayerController controller, double targetSeconds, int requestId) {
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (videoPlayerDisposed ||
          requestId != _initRequestId ||
          videoPlayerController != controller) {
        timer.cancel();
        return;
      }

      attempts++;
      final duration = controller.value.duration.inMilliseconds;

      // Khi video đã load được duration hoặc thử quá 15 lần (3 giây), tiến hành thực hiện seekTo
      if (duration > 0 || attempts > 15) {
        timer.cancel();
        try {
          await controller.seekTo(Duration(seconds: targetSeconds.toInt()));
          debugPrint('--> ĐÃ TUA THÀNH CÔNG ĐẾN GIÂY: $targetSeconds');
        } catch (e) {
          debugPrint('Lỗi khi gọi seekTo: $e');
        }
      }
    });
  }

  void checkTimer() {
    if (videoPlayerDisposed ||
        !videoPlayerInitialized ||
        videoPlayerController == null ||
        _targetSeekMilliseconds > 0) {
      return;
    }

    try {
      final controller = videoPlayerController!;
      nowTime = parseTotalTime(
        controller.value.position.inMilliseconds,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> onPlay() async {
    if (videoPlayerDisposed ||
        !videoPlayerInitialized ||
        videoPlayerController == null) {
      return;
    }

    activeControls();
    final controller = videoPlayerController!;

    try {
      if (isPlaying) {
        await controller.pause();
        if (videoPlayerDisposed) return;
        isPlaying = false;
      } else {
        await controller.play();
        if (videoPlayerDisposed) return;
        isPlaying = true;
      }

      checkTimer();
      notifyListeners();
    } catch (_) {}
  }

  int _getAcceleratedStep() {
    _consecutivePressCount++;

    _accelerationResetTimer?.cancel();
    _accelerationResetTimer = Timer(const Duration(milliseconds: 800), () {
      _consecutivePressCount = 0;
    });

    if (_consecutivePressCount > 10) {
      return timerBackorForwardMilliseconds * 10;
    } else if (_consecutivePressCount > 6) {
      return timerBackorForwardMilliseconds * 5;
    } else if (_consecutivePressCount > 3) {
      return timerBackorForwardMilliseconds * 2;
    }
    return timerBackorForwardMilliseconds;
  }

  Future<void> goForward() async {
    if (videoPlayerDisposed ||
        !videoPlayerInitialized ||
        videoPlayerController == null) {
      return;
    }

    activeControls();

    try {
      final controller = videoPlayerController!;
      final int max = controller.value.duration.inMilliseconds.round();
      final int current = controller.value.position.inMilliseconds.round();

      if (_targetSeekMilliseconds == 0 || _targetSeekMilliseconds < current) {
        _targetSeekMilliseconds = current;
      }

      final int step = _getAcceleratedStep();
      _targetSeekMilliseconds += step;

      if (_targetSeekMilliseconds > max) {
        _targetSeekMilliseconds = max;
      }

      nowTime = parseTotalTime(_targetSeekMilliseconds);
      notifyListeners();

      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = Timer(const Duration(milliseconds: 150), () async {
        if (videoPlayerDisposed || videoPlayerController == null) return;
        try {
          await controller
              .seekTo(Duration(milliseconds: _targetSeekMilliseconds));
        } catch (_) {}
        _targetSeekMilliseconds = 0;
      });
    } catch (_) {}
  }

  Future<void> goBack() async {
    if (videoPlayerDisposed ||
        !videoPlayerInitialized ||
        videoPlayerController == null) {
      return;
    }

    activeControls();

    try {
      final controller = videoPlayerController!;
      final int current = controller.value.position.inMilliseconds.round();

      if (_targetSeekMilliseconds == 0 || _targetSeekMilliseconds > current) {
        _targetSeekMilliseconds = current;
      }

      final int step = _getAcceleratedStep();
      _targetSeekMilliseconds -= step;

      if (_targetSeekMilliseconds < 0) {
        _targetSeekMilliseconds = 0;
      }

      nowTime = parseTotalTime(_targetSeekMilliseconds);
      notifyListeners();

      _seekDebounceTimer?.cancel();
      _seekDebounceTimer = Timer(const Duration(milliseconds: 150), () async {
        if (videoPlayerDisposed || videoPlayerController == null) return;
        try {
          await controller
              .seekTo(Duration(milliseconds: _targetSeekMilliseconds));
        } catch (_) {}
        _targetSeekMilliseconds = 0;
      });
    } catch (_) {}
  }

  Future<bool> changeVideo(String url) async {
    if (_changingVideo || videoPlayerDisposed || url.trim().isEmpty) {
      return false;
    }

    _changingVideo = true;

    try {
      await init(url);
      return true;
    } finally {
      _changingVideo = false;
    }
  }

  void activeControls() {
    if (videoPlayerDisposed) {
      return;
    }

    timer?.cancel();
    controlsVisible = true;
    notifyListeners();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    timer?.cancel();

    timer = Timer(
      const Duration(seconds: 7),
      () {
        if (videoPlayerDisposed) {
          return;
        }

        controlsVisible = false;
        if (onHideControls != null) {
          onHideControls!();
        }
        notifyListeners();
      },
    );
  }

  void _cancelTimers() {
    timer?.cancel();
    timer = null;

    timerTrackVideo?.cancel();
    timerTrackVideo = null;

    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = null;

    _accelerationResetTimer?.cancel();
    _accelerationResetTimer = null;

    _targetSeekMilliseconds = 0;
    _consecutivePressCount = 0;
  }

  Future<void> disposeVideoPlayer() async {
    if (videoPlayerDisposed) return;
    _initRequestId++;
    videoPlayerDisposed = true;
    _cancelTimers();
    final controller = videoPlayerController;
    videoPlayerController = null;
    videoPlayerInitialized = false;
    isPlaying = false;
    controlsVisible = false;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
    notifyListeners();
  }

  @override
  void dispose() {
    videoPlayerDisposed = true;
    _initRequestId++;
    _cancelTimers();
    final controller = videoPlayerController;
    videoPlayerController = null;
    try {
      controller?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
