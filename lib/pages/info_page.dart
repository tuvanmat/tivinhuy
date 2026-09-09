import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/services/license_service.dart';
import 'package:tv_flutter_app/services/update_service.dart';
import 'package:tv_flutter_app/utils/labels.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String _currentVersion = '1.0.0';
  String _remoteVersion = '';
  String _updateMessage = '';
  String _apkUrl = '';
  String _fileSize = '';
  bool _hasUpdate = false;
  bool _isLoading = true;

  final TextEditingController _keyController = TextEditingController();
  bool _isActivating = false;
  String _activationMessage = '';
  bool _isActivatedSuccess = false;
  String _licenseStatusText = 'Đang kiểm tra bản quyền...';
  String _displayedDeviceId = '';

  final FocusNode _updateButtonFocusNode =
      FocusNode(debugLabel: 'InfoUpdateButtonFocus');
  final FocusNode _keyFieldFocusNode =
      FocusNode(debugLabel: 'InfoKeyFieldFocus');
  final FocusNode _activateButtonFocusNode =
      FocusNode(debugLabel: 'InfoActivateButtonFocus');

  @override
  void initState() {
    super.initState();
    _initInfoData();
  }

  Future<void> _initInfoData() async {
    // Lấy deviceId trước tiên để hiển thị ngay lập tức lên màn hình Tivi
    String id = await LicenseService.getDeviceId();
    if (mounted) {
      setState(() {
        _displayedDeviceId = id;
      });
    }

    // Sau đó kiểm tra thông tin app và bản quyền
    await _checkAppInfo();
    await _checkLicenseStatus();
  }

  @override
  void dispose() {
    _updateButtonFocusNode.dispose();
    _keyFieldFocusNode.dispose();
    _activateButtonFocusNode.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _checkAppInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(UpdateService.versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _remoteVersion = data['versionName'] ?? '1.0.0';
        _apkUrl = data['apkUrl'] ?? '';
        _updateMessage = data['updateMessage'] ??
            'Đã có phiên bản mới trên tivi, cập nhật ngay nhé!';
        _fileSize = data['fileSize'] ?? '';

        if (UpdateService.isNewerVersion(_currentVersion, _remoteVersion)) {
          _hasUpdate = true;
        }
      }
    } catch (e) {
      debugPrint('Lỗi lấy thông tin phiên bản: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLicenseStatus() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://trongnga.io.vn/app/license_api.php?action=check&device_id=${LicenseService.deviceId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String status = data['status'];

        if (mounted) {
          setState(() {
            if (status == 'active') {
              _isActivatedSuccess = true;
              _activationMessage =
                  "Ứng dụng đã được kích hoạt bản quyền đầy đủ.";
              _licenseStatusText = "Đã kích hoạt vĩnh viễn";
            } else if (status == 'trial') {
              _isActivatedSuccess = false;
              int daysLeft = data['days_left'] ?? 30;
              _licenseStatusText = "Đang dùng thử (Còn $daysLeft ngày)";
            } else {
              _isActivatedSuccess = false;
              _licenseStatusText = "Thời gian dùng thử đã hết";
            }
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Lỗi check license status: $e');
    }

    bool active = await LicenseService.checkAppLicense();
    if (mounted) {
      setState(() {
        _isActivatedSuccess = active;
        if (active) {
          _activationMessage = "Ứng dụng đã được kích hoạt bản quyền đầy đủ.";
          _licenseStatusText = "Đã kích hoạt vĩnh viễn";
        } else {
          _licenseStatusText = "Cần kích hoạt bản quyền";
        }
      });
    }
  }

  void _submitKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _activationMessage = "Vui lòng nhập mã kích hoạt!";
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _activationMessage = "";
    });

    final result = await LicenseService.activateKey(key);

    if (mounted) {
      setState(() {
        _isActivating = false;
        _activationMessage = result['message'];
        if (result['status'] == 'success') {
          _isActivatedSuccess = true;
          _licenseStatusText = "Đã kích hoạt vĩnh viễn";
        }
      });
    }
  }

  void _returnToHomeSidebar(BuildContext context) {
    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);
    buttonFocusProvider.buttonFocusedLabel = sidebarHomeOption;
    buttonFocusProvider.lastButtonFocusedLabel = sidebarHomeOption;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final buttonFocusProvider =
              Provider.of<ButtonFocusProvider>(context, listen: false);
          buttonFocusProvider.buttonFocusedLabel = sidebarHomeOption;
          buttonFocusProvider.lastButtonFocusedLabel = sidebarHomeOption;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/welcome_bg.jpg',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => _returnToHomeSidebar(context),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 40.0, horizontal: 40.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Container(
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 35,
                            offset: Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isLoading
                                ? 'Đang kiểm tra thông tin phiên bản...'
                                : _hasUpdate
                                    ? _updateMessage
                                    : 'Ứng dụng đang ở phiên bản mới nhất (v$_currentVersion)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _hasUpdate
                                  ? Colors.amberAccent
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildBadge(
                                icon: Icons.fork_right,
                                iconColor: Colors.redAccent,
                                text:
                                    'Phiên bản: ${_hasUpdate ? _remoteVersion : _currentVersion}',
                              ),
                              _buildBadge(
                                icon: Icons.verified_user,
                                iconColor: _isActivatedSuccess
                                    ? Colors.greenAccent
                                    : Colors.amber,
                                text: 'Trạng thái: $_licenseStatusText',
                              ),
                              _buildBadge(
                                icon: Icons.tv,
                                iconColor: Colors.amber,
                                text:
                                    'Mã Tivi: ${_displayedDeviceId.isNotEmpty ? _displayedDeviceId : "Đang lấy..."}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (!_isActivatedSuccess)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kích Hoạt Bản Quyền Ứng Dụng',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _keyController,
                                          focusNode: _keyFieldFocusNode,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onSubmitted: (_) => _submitKey(),
                                          decoration: InputDecoration(
                                            hintText: 'Nhập mã bản quyền...',
                                            hintStyle: const TextStyle(
                                                color: Colors.white54),
                                            filled: true,
                                            fillColor: const Color(0xFF222222),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 48,
                                        child: AnimatedBuilder(
                                          animation: _activateButtonFocusNode,
                                          builder: (context, child) {
                                            final isFocused =
                                                _activateButtonFocusNode
                                                    .hasFocus;
                                            return ElevatedButton(
                                              focusNode:
                                                  _activateButtonFocusNode,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.amber,
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                    color: isFocused
                                                        ? Colors.white
                                                        : Colors.transparent,
                                                    width: 2.5,
                                                  ),
                                                ),
                                                elevation: isFocused ? 8 : 2,
                                              ),
                                              onPressed: _isActivating
                                                  ? null
                                                  : _submitKey,
                                              child: _isActivating
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    )
                                                  : const Text(
                                                      'Kích Hoạt',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_activationMessage.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      _activationMessage,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.greenAccent
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle,
                                      color: Colors.greenAccent, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Đã kích hoạt bản quyền vĩnh viễn thành công!',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (_hasUpdate)
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedBuilder(
                                animation: _updateButtonFocusNode,
                                builder: (context, child) {
                                  final isFocused =
                                      _updateButtonFocusNode.hasFocus;
                                  return ElevatedButton.icon(
                                    focusNode: _updateButtonFocusNode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50914),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isFocused
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 3.0,
                                        ),
                                      ),
                                      elevation: isFocused ? 12 : 4,
                                    ),
                                    onPressed: () {
                                      UpdateService.downloadAndInstallDirect(
                                          context, _apkUrl);
                                    },
                                    icon: const Icon(Icons.download,
                                        size: 22, color: Colors.white),
                                    label: const Text(
                                      'Tải Về Cài Đặt (APK Mới)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
      {required IconData icon,
      required Color iconColor,
      required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
