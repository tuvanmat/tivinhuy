import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_service.dart';

/// Các pha của khối "Cập nhật ứng dụng" trên trang Thông tin.
/// - checking: đang hỏi server bản mới nhất
/// - latest: đang ở bản mới nhất
/// - available: có bản mới, chưa tải
/// - downloading: đang tải (có % tiến trình)
/// - downloaded: đã tải xong, file nằm chờ người dùng nhấn Cập nhật ngay
/// - interrupted: tải bị gián đoạn (mất mạng/huỷ) — phần đã tải được giữ lại
/// - failed: lỗi khác (ví dụ file tải về không khớp mã SHA-256)
enum UpdatePhase {
  checking,
  latest,
  available,
  downloading,
  downloaded,
  interrupted,
  failed,
}

enum OtherAppPhase { idle, loading, ready, downloading, downloaded, failed }

class OtherApp {
  final String id;
  final String name;
  final String subtitle;
  final int colorValue;
  final String logoAsset;
  final String versionUrl;

  OtherAppPhase phase = OtherAppPhase.idle;
  String remoteVersion = '';
  String remoteSize = '';
  String apkUrl = '';
  double progress = 0;

  OtherApp({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.colorValue,
    required this.logoAsset,
    required this.versionUrl,
  });
}

/// Quản lý cập nhật tập trung cho trang Thông tin:
/// kiểm tra bản mới, tải nền có % + tải tiếp khi gián đoạn, giữ file
/// đã tải ở trạng thái chờ, và tự xoá file sau khi cập nhật hoàn thành.
/// Dữ liệu trạng thái lưu bằng file JSON trong thư mục riêng của app
/// (không cần thêm gói shared_preferences).
class AppUpdateManager extends ChangeNotifier {
  AppUpdateManager._();
  static final AppUpdateManager instance = AppUpdateManager._();

  static const MethodChannel _platform =
      MethodChannel('com.tivi.nhuy/installer');

  /// 3 ứng dụng còn lại hiện ở cuối trang Thông tin của bản đỏ.
  final List<OtherApp> otherApps = [
    OtherApp(
      id: 'phim',
      name: 'Phim Như Ý',
      subtitle: 'Ứng dụng xem phim',
      colorValue: 0xFFEA491F,
      logoAsset: 'assets/images/apps/phim.png',
      versionUrl: 'https://trongnga.io.vn/app/version.json',
    ),
    OtherApp(
      id: 'v1',
      name: 'Phim Như Ý V1',
      subtitle: 'Ứng dụng xem phim',
      colorValue: 0xFF2883E1,
      logoAsset: 'assets/images/apps/v1.png',
      versionUrl: 'https://trongnga.io.vn/app/v1/version.json',
    ),
    OtherApp(
      id: 'v2',
      name: 'Phim Như Ý V2',
      subtitle: 'Ứng dụng xem phim',
      colorValue: 0xFFBA48EF,
      logoAsset: 'assets/images/apps/v2.png',
      versionUrl: 'https://trongnga.io.vn/app/v2/version.json',
    ),
  ];

  bool _initialized = false;
  String currentVersion = '';
  UpdatePhase phase = UpdatePhase.checking;
  String remoteVersion = '';
  String remoteMessage = '';
  String remoteSize = '';
  String _apkUrl = '';
  String _remoteSha256 = '';
  DateTime? lastCheckAt;

  double progress = 0;
  int receivedBytes = 0;
  int totalBytes = 0;
  double speedMBs = 0;
  String errorText = '';

  CancelToken? _cancelToken;
  bool _downloading = false;

  // ---------- Khởi tạo + dọn dẹp ----------

  Future<Directory> _updatesDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/updates');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _stateFile() async {
    final dir = await _updatesDir();
    return File('${dir.path}/update_state.json');
  }

  Future<File> _finalApk() async {
    final dir = await _updatesDir();
    return File('${dir.path}/truyenhinh-update.apk');
  }

  Future<File> _partApk() async {
    final dir = await _updatesDir();
    return File('${dir.path}/truyenhinh-update.apk.part');
  }

  Future<Map<String, dynamic>?> _readState() async {
    try {
      final f = await _stateFile();
      if (await f.exists()) {
        return json.decode(await f.readAsString()) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Lỗi đọc update_state: $e');
    }
    return null;
  }

  Future<void> _writeState(Map<String, dynamic>? data) async {
    try {
      final f = await _stateFile();
      if (data == null) {
        if (await f.exists()) await f.delete();
      } else {
        await f.writeAsString(json.encode(data));
      }
    } catch (e) {
      debugPrint('Lỗi ghi update_state: $e');
    }
  }

  /// Gọi khi mở trang Thông tin: nạp trạng thái đã lưu và dọn file cập
  /// nhật đã cài xong. Quy tắc xoá sau cập nhật: nếu bản đang chạy đã
  /// bằng hoặc mới hơn bản từng tải về thì file tải về không còn cần
  /// nữa — xoá file + xoá trạng thái.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (_) {}

    final state = await _readState();
    if (state != null && state['downloaded'] == true) {
      final downloadedVersion = (state['version'] ?? '') as String;
      if (downloadedVersion.isNotEmpty &&
          !UpdateService.isNewerVersion(currentVersion, downloadedVersion)) {
        // Đã cập nhật lên bản này (hoặc mới hơn) → xoá file như đã hứa.
        final f = await _finalApk();
        if (await f.exists()) await f.delete();
        final p = await _partApk();
        if (await p.exists()) await p.delete();
        await _writeState(null);
      } else {
        final f = await _finalApk();
        if (await f.exists() && await f.length() > 0) {
          remoteVersion = downloadedVersion;
          remoteMessage = (state['message'] ?? '') as String;
          remoteSize = (state['size'] ?? '') as String;
          _apkUrl = (state['url'] ?? '') as String;
          _remoteSha256 = (state['sha'] ?? '') as String;
          phase = UpdatePhase.downloaded;
          notifyListeners();
        }
      }
    }

    // Đánh dấu sẵn các app khác đã tải xong từ lần trước.
    final dir = await _updatesDir();
    for (final app in otherApps) {
      final f = File('${dir.path}/other-${app.id}.apk');
      if (await f.exists() && await f.length() > 0) {
        app.phase = OtherAppPhase.downloaded;
      }
    }
  }

  // ---------- Kiểm tra bản mới ----------

  Future<void> checkForUpdate() async {
    if (_downloading) return;
    phase = UpdatePhase.checking;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(UpdateService.versionUrl))
          .timeout(const Duration(seconds: 15));
      lastCheckAt = DateTime.now();
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rv = (data['versionName'] ?? '') as String;
        if (rv.isNotEmpty &&
            UpdateService.isNewerVersion(currentVersion, rv)) {
          // Nếu đang giữ một bản đã tải mà server có bản còn mới hơn
          // nữa thì bản đã tải đã lỗi thời — xoá đi.
          if (phase == UpdatePhase.downloaded && rv != remoteVersion) {
            await deleteDownloaded(silent: true);
          }
          remoteVersion = rv;
          remoteMessage = (data['updateMessage'] ?? '') as String;
          remoteSize = (data['fileSize'] ?? '') as String;
          _apkUrl = (data['apkUrl'] ?? '') as String;
          _remoteSha256 = (data['sha256'] ?? '') as String;
          if (phase != UpdatePhase.downloaded) {
            // Còn file tải dở của đúng bản này thì báo gián đoạn để
            // người dùng tải tiếp thay vì tải lại từ đầu.
            final part = await _partApk();
            if (await part.exists() && await part.length() > 0) {
              receivedBytes = await part.length();
              phase = UpdatePhase.interrupted;
            } else {
              phase = UpdatePhase.available;
            }
          }
        } else {
          phase = UpdatePhase.latest;
        }
      } else {
        phase = UpdatePhase.latest;
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra cập nhật: $e');
      // Không hỏi được server: giữ nguyên trạng thái đã biết.
      if (phase == UpdatePhase.checking) phase = UpdatePhase.latest;
    }
    notifyListeners();
  }

  // ---------- Tải bản cập nhật ----------

  Future<void> startDownload({bool restart = false}) async {
    if (_downloading || _apkUrl.isEmpty) return;
    _downloading = true;
    phase = UpdatePhase.downloading;
    errorText = '';
    notifyListeners();

    final part = await _partApk();
    if (restart && await part.exists()) await part.delete();

    _cancelToken = CancelToken();
    final dio = Dio();
    int lastBytes = 0;
    DateTime lastTick = DateTime.now();

    try {
      int existing = 0;
      if (await part.exists()) existing = await part.length();

      final resp = await dio.get<ResponseBody>(
        _apkUrl,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 30),
        ),
      );

      final status = resp.statusCode ?? 200;
      final canResume = status == 206 && existing > 0;
      if (!canResume) existing = 0;
      receivedBytes = existing;
      final contentLength =
          int.tryParse(resp.headers.value('content-length') ?? '') ?? 0;
      totalBytes = contentLength > 0 ? contentLength + existing : 0;
      lastBytes = existing;
      lastTick = DateTime.now();

      final sink = part.openWrite(
          mode: canResume ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in resp.data!.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final now = DateTime.now();
          final dt = now.difference(lastTick).inMilliseconds;
          if (dt >= 300) {
            speedMBs = (receivedBytes - lastBytes) / dt * 1000 / 1048576;
            lastBytes = receivedBytes;
            lastTick = now;
            if (totalBytes > 0) progress = receivedBytes / totalBytes;
            notifyListeners();
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (totalBytes > 0 && receivedBytes < totalBytes) {
        throw DioException(
          requestOptions: resp.requestOptions,
          type: DioExceptionType.receiveTimeout,
          message: 'Luồng tải kết thúc sớm',
        );
      }

      // Kiểm tra toàn vẹn trước khi cho phép cài.
      if (_remoteSha256.isNotEmpty) {
        final digest = await sha256.bind(part.openRead()).first;
        if (digest.toString().toLowerCase() !=
            _remoteSha256.trim().toLowerCase()) {
          await part.delete();
          phase = UpdatePhase.failed;
          errorText =
              'File tải về không khớp mã kiểm tra an toàn (SHA-256) nên đã bị xoá. Hãy tải lại.';
          _downloading = false;
          notifyListeners();
          return;
        }
      }

      final fin = await _finalApk();
      if (await fin.exists()) await fin.delete();
      await part.rename(fin.path);
      await _writeState({
        'downloaded': true,
        'version': remoteVersion,
        'message': remoteMessage,
        'size': remoteSize,
        'url': _apkUrl,
        'sha': _remoteSha256,
      });
      progress = 1;
      phase = UpdatePhase.downloaded;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        phase = UpdatePhase.interrupted;
        errorText = 'Đã huỷ tải. Phần đã tải vẫn được giữ để tải tiếp.';
      } else {
        phase = UpdatePhase.interrupted;
        errorText =
            'Tải bị gián đoạn. Phần đã tải vẫn được giữ — kiểm tra mạng rồi tải tiếp.';
      }
      debugPrint('Lỗi tải cập nhật: $e');
    } catch (e) {
      phase = UpdatePhase.interrupted;
      errorText =
          'Tải bị gián đoạn. Phần đã tải vẫn được giữ — kiểm tra mạng rồi tải tiếp.';
      debugPrint('Lỗi tải cập nhật: $e');
    }

    _downloading = false;
    notifyListeners();
  }

  void cancelDownload() {
    _cancelToken?.cancel('user-cancel');
  }

  Future<void> deleteDownloaded({bool silent = false}) async {
    final f = await _finalApk();
    if (await f.exists()) await f.delete();
    final p = await _partApk();
    if (await p.exists()) await p.delete();
    await _writeState(null);
    if (!silent) {
      phase = remoteVersion.isNotEmpty &&
              UpdateService.isNewerVersion(currentVersion, remoteVersion)
          ? UpdatePhase.available
          : UpdatePhase.latest;
      notifyListeners();
    }
  }

  Future<void> installDownloaded() async {
    final f = await _finalApk();
    if (await f.exists()) {
      await _installApkNative(f.path);
    }
  }

  // ---------- Tải các ứng dụng khác ----------

  Future<void> fetchOtherAppsInfo() async {
    for (final app in otherApps) {
      if (app.phase == OtherAppPhase.downloading) continue;
      if (app.phase == OtherAppPhase.idle) {
        app.phase = OtherAppPhase.loading;
      }
      try {
        final r = await http
            .get(Uri.parse(app.versionUrl))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final data = json.decode(r.body) as Map<String, dynamic>;
          app.remoteVersion = (data['versionName'] ?? '') as String;
          app.remoteSize = (data['fileSize'] ?? '') as String;
          app.apkUrl = (data['apkUrl'] ?? '') as String;
          if (app.phase == OtherAppPhase.loading) {
            app.phase = OtherAppPhase.ready;
          }
        }
      } catch (e) {
        debugPrint('Lỗi lấy thông tin ${app.id}: $e');
        if (app.phase == OtherAppPhase.loading) {
          app.phase = OtherAppPhase.ready;
        }
      }
    }
    notifyListeners();
  }

  Future<void> downloadOtherApp(OtherApp app) async {
    if (app.phase == OtherAppPhase.downloading || app.apkUrl.isEmpty) return;
    app.phase = OtherAppPhase.downloading;
    app.progress = 0;
    notifyListeners();

    try {
      final dir = await _updatesDir();
      final savePath = '${dir.path}/other-${app.id}.apk';
      final dio = Dio();
      await dio.download(
        app.apkUrl,
        savePath,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            app.progress = received / total;
            notifyListeners();
          }
        },
      );
      app.phase = OtherAppPhase.downloaded;
    } catch (e) {
      debugPrint('Lỗi tải ${app.id}: $e');
      app.phase = OtherAppPhase.failed;
    }
    notifyListeners();
  }

  Future<void> deleteOtherApp(OtherApp app) async {
    final dir = await _updatesDir();
    final f = File('${dir.path}/other-${app.id}.apk');
    if (await f.exists()) await f.delete();
    app.phase = OtherAppPhase.ready;
    notifyListeners();
  }

  Future<void> installOtherApp(OtherApp app) async {
    final dir = await _updatesDir();
    final f = File('${dir.path}/other-${app.id}.apk');
    if (await f.exists()) {
      await _installApkNative(f.path);
    }
  }

  static Future<void> _installApkNative(String filePath) async {
    try {
      await _platform.invokeMethod('installApk', {'filePath': filePath});
    } on PlatformException catch (e) {
      debugPrint('Không thể cài đặt APK: ${e.message}');
    }
  }
}
