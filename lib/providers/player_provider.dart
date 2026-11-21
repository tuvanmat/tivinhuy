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
  Timer? _seekDebounceTimer;
  Timer? _accelerationResetTimer;
  Timer? _retryTimer;

  int _targetSeekMilliseconds = 0;
  int _consecutivePressCount = 0;
  int _retryCount = 0;
  String _currentStreamUrl = '';

  bool controlsVisible = true;
  bool isPlaying = false;

  bool _changingVideo = false;
  bool get changingVideo => _changingVideo;

  int _initRequestId = 0;
  double _pendingInitialSeek = 0.0;
  bool _hasSeekedInitial = false;

  VoidCallback? onHideControls;
  VoidCallback? onError;

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

    _currentStreamUrl = url.trim();
    final int requestId = ++_initRequestId;
    _pendingInitialSeek = initialPositionSeconds;
    _hasSeekedInitial = false;

    videoPlayerInitialized = false;
    isPlaying = false;
    controlsVisible = true;

    notifyListeners();
    _cancelTimers();

    final oldController = videoPlayerController;
    if (oldController != null) {
      try {
        await oldController.pause();
        oldController.removeListener(_videoListener);
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

    String targetUrl = _currentStreamUrl;

    if (targetUrl.startsWith('udp://') || targetUrl.startsWith('rtp://')) {
      debugPrint(
          'Lỗi: Giao thức UDP/RTP chưa được hỗ trợ trực tiếp: $targetUrl');
      videoPlayerInitialized = false;
      isPlaying = false;
      notifyListeners();
      onError?.call();
      return;
    }

    if (!targetUrl.startsWith('http')) {
      targetUrl = 'https:$targetUrl';
    }

    debugPrint(
        'Đang tiến hành phát video từ URL: $targetUrl (Thử nghiệm lần: ${_retryCount + 1})');

    // Cấu hình Headers tương thích tối đa cho điện thoại Android (giả lập trình duyệt Chrome Mobile)
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(targetUrl),
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
        'Icy-Metadata': '1',
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

      _retryCount = 0;

      await controller.setVolume(1.0);
      videoPlayerInitialized = true;

      totalTime = parseTotalTime(
        controller.value.duration.inMilliseconds.round(),
      );

      nowTime = parseTotalTime(
        controller.value.position.inMilliseconds.round(),
      );

      controller.addListener(_videoListener);

      await controller.play();

      if (requestId != _initRequestId ||
          videoPlayerDisposed ||
          videoPlayerController != controller) {
        return;
      }

      isPlaying = true;
      notifyListeners();

      if (_pendingInitialSeek > 0) {
        Future.delayed(const Duration(milliseconds: 400), () async {
          if (videoPlayerDisposed ||
              requestId != _initRequestId ||
              videoPlayerController != controller) {
            return;
          }
          try {
            await controller
                .seekTo(Duration(seconds: _pendingInitialSeek.toInt()));
          } catch (e) {
            debugPrint('Lỗi khi gọi delayed seekTo: $e');
          }
        });

        _performAccurateSeek(controller, _pendingInitialSeek, requestId);
      }

      _startControlsTimer();
    } catch (e) {
      debugPrint(
          'Lỗi khởi tạo video player trên điện thoại với URL $targetUrl: $e');
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

      if (_retryCount < 2 && _currentStreamUrl.isNotEmpty) {
        _retryCount++;
        debugPrint(
            'Đang tự động kết nối lại kênh trên điện thoại (Lần thử $_retryCount)...');
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 1), () {
          if (!videoPlayerDisposed) {
            init(_currentStreamUrl,
                initialPositionSeconds: initialPositionSeconds);
          }
        });
      } else {
        onError?.call();
      }
    }
  }

  void _videoListener() {
    if (videoPlayerDisposed ||
        !videoPlayerInitialized ||
        videoPlayerController == null) {
      return;
    }

    try {
      final controller = videoPlayerController!;

      if (controller.value.hasError) {
        debugPrint(
            'Phát hiện lỗi luồng trên điện thoại: ${controller.value.errorDescription}');
        onError?.call();
      }

      if (!_hasSeekedInitial &&
          _pendingInitialSeek > 0 &&
          controller.value.isInitialized) {
        final currentPosMs = controller.value.position.inMilliseconds;
        if (currentPosMs > 300 &&
            currentPosMs < (_pendingInitialSeek * 1000 - 1000)) {
          _hasSeekedInitial = true;
          controller.seekTo(Duration(seconds: _pendingInitialSeek.toInt()));
        }
      }

      final currentPos = controller.value.position.inMilliseconds;
      final formattedTime = parseTotalTime(currentPos);

      if (nowTime != formattedTime && _targetSeekMilliseconds == 0) {
        nowTime = formattedTime;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _performAccurateSeek(
      VideoPlayerController controller, double targetSeconds, int requestId) {
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (videoPlayerDisposed ||
          requestId != _initRequestId ||
          videoPlayerController != controller) {
        timer.cancel();
        return;
      }

      attempts++;
      try {
        await controller.seekTo(Duration(seconds: targetSeconds.toInt()));
      } catch (e) {
        debugPrint('Lỗi khi gọi seekTo: $e');
      }

      if (attempts >= 4) {
        timer.cancel();
      }
    });
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

  Future<bool> changeVideo(String url,
      {double initialPositionSeconds = 0.0}) async {
    if (_changingVideo || videoPlayerDisposed || url.trim().isEmpty) {
      return false;
    }

    _changingVideo = true;
    _retryCount = 0;

    try {
      await init(url, initialPositionSeconds: initialPositionSeconds);
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

    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = null;

    _accelerationResetTimer?.cancel();
    _accelerationResetTimer = null;

    _retryTimer?.cancel();
    _retryTimer = null;

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
        controller.removeListener(_videoListener);
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
      controller?.removeListener(_videoListener);
      controller?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
