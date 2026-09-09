import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String versionUrl = 'https://trongnga.io.vn/app/version.json';
  static const MethodChannel _platform =
      MethodChannel('com.phim.nhuy/installer');

  // Hàm so sánh phiên bản công khai để InfoPage dùng
  static bool isNewerVersion(String current, String remote) {
    List<String> currentParts = current.split('.');
    List<String> remoteParts = remote.split('.');

    for (int i = 0; i < remoteParts.length; i++) {
      int rNum = int.tryParse(remoteParts[i]) ?? 0;
      int cNum =
          i < currentParts.length ? (int.tryParse(currentParts[i]) ?? 0) : 0;

      if (rNum > cNum) return true;
      if (rNum < cNum) return false;
    }
    return false;
  }

  // Hàm thực hiện tải và cài đặt trực tiếp khi người dùng bấm nút trong trang Info
  static Future<void> downloadAndInstallDirect(
      BuildContext context, String apkUrl) async {
    ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {
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
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.amber),
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
      Directory tempDir = await getTemporaryDirectory();
      String savePath = '${tempDir.path}/update.apk';

      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      Dio dio = Dio();
      await dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      await _installApkNative(savePath);
    } catch (e) {
      debugPrint('Lỗi tải file APK: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tải bản cập nhật thất bại. Vui lòng thử lại!')),
        );
      }
    }
  }

  static Future<void> _installApkNative(String filePath) async {
    try {
      @override
      final MethodChannel platform = MethodChannel('com.phim.nhuy/installer');
      await platform.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      debugPrint('Lỗi gọi cài đặt native: $e');
    }
  }
}
