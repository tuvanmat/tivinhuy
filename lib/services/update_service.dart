import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:tv_flutter_app/utils/app_colors.dart';

class UpdateService {
  static const String versionUrl =
      'https://trongnga.io.vn/app/tivi/version.json';

  static const MethodChannel _platform =
      MethodChannel('com.tivi.nhuy/installer');

  // Tên file APK lưu riêng cho app Tivi Như Ý.
  // Các phiên bản mới của cùng app sẽ thay thế file này.
  // App khác có thể dùng tên khác, ví dụ phim1.apk, phim2.apk...
  static const String localApkFileName = 'tivi.apk';

  static bool isNewerVersion(String current, String remote) {
    final currentParts = current.split('.');
    final remoteParts = remote.split('.');

    for (int i = 0; i < remoteParts.length; i++) {
      final rNum = int.tryParse(remoteParts[i]) ?? 0;
      final cNum = i < currentParts.length
          ? (int.tryParse(currentParts[i]) ?? 0)
          : 0;

      if (rNum > cNum) return true;
      if (rNum < cNum) return false;
    }
    return false;
  }

  static Future<void> downloadAndInstallDirect(
    BuildContext context,
    String apkUrl,
  ) async {
    final progressNotifier = ValueNotifier<double>(0.0);
    bool dialogClosed = false;

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (
        BuildContext buildContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return PopScope(
          canPop: false,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2430),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Đang tải bản cập nhật...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, value, child) {
                        return Column(
                          children: [
                            LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                AppColors.brandBright,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              '${(value * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Vui lòng không tắt ứng dụng trong quá trình tải.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$localApkFileName';
      final file = File(savePath);

      // Xóa bản APK cũ của chính app Tivi Như Ý.
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();

      await dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (!await file.exists()) {
        throw Exception('File APK không tồn tại sau khi tải.');
      }

      if (await file.length() <= 0) {
        throw Exception('File APK tải về bị rỗng.');
      }

      if (context.mounted && !dialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogClosed = true;
      }

      // Native:
      // - có quyền -> cài ngay;
      // - chưa có quyền -> mở Settings;
      // - quay lại app -> tự cài file đã tải, không tải lại.
      await _installApkNative(savePath);
    } catch (e) {
      if (context.mounted && !dialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogClosed = true;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể tải/cài đặt bản cập nhật: $e',
            ),
          ),
        );
      }

      debugPrint('Lỗi cập nhật APK: $e');
    } finally {
      progressNotifier.dispose();
    }
  }

  static Future<void> _installApkNative(String filePath) async {
    try {
      await _platform.invokeMethod(
        'installApk',
        {
          'filePath': filePath,
        },
      );
    } on PlatformException catch (e) {
      debugPrint('Không thể cài đặt APK: ${e.message}');
    }
  }
}
