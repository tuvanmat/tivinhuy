import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LicenseService {
  static bool isAllowedToWatch = false;
  static String deviceId = "";
  static String legacyDeviceId = "";

  static const String _apiUrl = "https://trongnga.io.vn/app/tivi/license_api.php";
  static const MethodChannel _platform =
      MethodChannel('com.tivi.nhuy/installer');

  // Mã máy CŨ (Build.ID): giữ nguyên cách lấy như các bản app trước để
  // gửi kèm dưới tên legacy_device_id. Server dựa vào mã cũ này để tự
  // chuyển dữ liệu của máy sang mã mới — khách cũ nâng cấp app sẽ
  // KHÔNG bị mất kích hoạt hay mất ngày dùng thử.
  static Future<String> getLegacyDeviceId() async {
    if (legacyDeviceId.isNotEmpty) return legacyDeviceId;

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        legacyDeviceId = androidInfo.id.isNotEmpty
            ? androidInfo.id
            : (androidInfo.device.isNotEmpty
                ? androidInfo.device
                : "TV_ANDROID_UNKNOWN");
      } else {
        legacyDeviceId = "emulator_test_id";
      }
    } catch (e) {
      debugPrint('Lỗi lấy Legacy Device ID: $e');
      legacyDeviceId = "TV_FALLBACK_ID_2026";
    }

    return legacyDeviceId;
  }

  // Mã máy MỚI: ANDROID_ID — duy nhất cho từng thiết bị thật, không
  // thay đổi khi cài lại app. Nếu thiết bị không cấp ANDROID_ID (hoặc
  // trả về mã dùng chung nổi tiếng của máy ảo đời cũ) thì dùng một mã
  // ngẫu nhiên sinh đúng một lần và lưu lại trong thư mục riêng của app.
  static Future<String> getDeviceId() async {
    if (deviceId.isNotEmpty) return deviceId;

    await getLegacyDeviceId();

    if (Platform.isAndroid) {
      try {
        final String? androidId =
            await _platform.invokeMethod<String>('getAndroidId');
        if (androidId != null &&
            androidId.isNotEmpty &&
            androidId != '9774d56d682e549c') {
          deviceId = androidId;
          return deviceId;
        }
      } catch (e) {
        debugPrint('Lỗi lấy Android ID: $e');
      }
    }

    try {
      deviceId = await _getOrCreateStoredUid();
    } catch (e) {
      debugPrint('Lỗi lấy mã máy dự phòng: $e');
      deviceId = legacyDeviceId;
    }

    return deviceId;
  }

  static Future<String> _getOrCreateStoredUid() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/device_uid.txt');
    if (await file.exists()) {
      final saved = (await file.readAsString()).trim();
      if (saved.isNotEmpty) return saved;
    }
    final rng = Random.secure();
    final uid =
        List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join();
    await file.writeAsString(uid);
    return uid;
  }

  static Future<bool> checkAppLicense() async {
    try {
      await getDeviceId();

      final response = await http
          .get(
            Uri.parse(
              '$_apiUrl?action=check'
              '&device_id=${Uri.encodeQueryComponent(deviceId)}'
              '&legacy_device_id=${Uri.encodeQueryComponent(legacyDeviceId)}',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String status = data['status'];

        if (status == 'active' || status == 'trial') {
          isAllowedToWatch = true;
          return true;
        }
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra bản quyền: $e');
      isAllowedToWatch = true;
      return true;
    }

    isAllowedToWatch = false;
    return false;
  }

  // Lấy trạng thái bản quyền chi tiết (status / days_left / message)
  // cho các màn hình hiển thị như trang thông tin. Bắt buộc đi qua
  // hàm này — KHÔNG tự gọi API ở nơi khác — vì lượt kiểm tra phải
  // luôn gửi kèm legacy_device_id để server tự chuyển đổi mã máy
  // cho khách cũ nâng cấp (thiếu mã cũ là máy bị tính dùng thử mới).
  static Future<Map<String, dynamic>?> fetchLicenseStatus() async {
    try {
      await getDeviceId();

      final response = await http
          .get(
            Uri.parse(
              '$_apiUrl?action=check'
              '&device_id=${Uri.encodeQueryComponent(deviceId)}'
              '&legacy_device_id=${Uri.encodeQueryComponent(legacyDeviceId)}',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Lỗi lấy trạng thái bản quyền: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> activateKey(String key) async {
    try {
      await getDeviceId();

      final response = await http
          .post(
            Uri.parse('$_apiUrl?action=activate'),
            body: {
              'device_id': deviceId,
              'legacy_device_id': legacyDeviceId,
              'key': key,
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          isAllowedToWatch = true;
        }
        return result;
      }
    } catch (e) {
      debugPrint('Lỗi kích hoạt Key: $e');
    }
    return {"status": "error", "message": "Lỗi kết nối đến máy chủ kích hoạt!"};
  }
}
