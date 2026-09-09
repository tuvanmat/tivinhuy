import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class LicenseService {
  static bool isAllowedToWatch = false;
  static String deviceId = "";

  static const String _apiUrl = "https://trongnga.io.vn/app/license_api.php";

  // Hàm lấy Device ID chuẩn xác, đảm bảo không bao giờ bị trống
  static Future<String> getDeviceId() async {
    if (deviceId.isNotEmpty) return deviceId;

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id.isNotEmpty
            ? androidInfo.id
            : (androidInfo.device.isNotEmpty
                ? androidInfo.device
                : "TV_ANDROID_UNKNOWN");
      } else {
        deviceId = "emulator_test_id";
      }
    } catch (e) {
      debugPrint('Lỗi lấy Device ID: $e');
      deviceId = "TV_FALLBACK_ID_2026";
    }

    return deviceId;
  }

  static Future<bool> checkAppLicense() async {
    try {
      await getDeviceId();

      final response = await http.get(
        Uri.parse('$_apiUrl?action=check&device_id=$deviceId'),
      );

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

  static Future<Map<String, dynamic>> activateKey(String key) async {
    try {
      await getDeviceId();

      final response = await http.post(
        Uri.parse('$_apiUrl?action=activate'),
        body: {
          'device_id': deviceId,
          'key': key,
        },
      );

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
