import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/services/app_update_manager.dart';
import 'package:tv_flutter_app/services/license_service.dart';
import 'package:tv_flutter_app/utils/labels.dart';

const Color _accent = Color(0xFFD80000);
const Color _nameRed = Color(0xFFD80000);
const Color _cardBg = Color(0xFF17171D);
const Color _cardBorder = Color(0xFF26262F);

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final AppUpdateManager _upd = AppUpdateManager.instance;

  String _deviceId = '';
  String _licenseChipText = 'Đang kiểm tra bản quyền...';
  String _licensePlanText = '';
  int _licenseChipKind = 1; // 0 = đã kích hoạt, 1 = dùng thử/trung tính, 2 = đã khoá
  bool _isPermanentActive = false;
  bool _isTimedActive = false;

  final FocusNode _backFocus = FocusNode(debugLabel: 'InfoBack');
  final FocusNode _keyFocus = FocusNode(debugLabel: 'InfoKeyBtn');
  final FocusNode _checkFocus = FocusNode(debugLabel: 'InfoCheckBtn');
  final FocusNode _primaryFocus = FocusNode(debugLabel: 'InfoPrimaryBtn');
  final FocusNode _secondaryFocus = FocusNode(debugLabel: 'InfoSecondaryBtn');
  final Map<String, FocusNode> _appFocus = {};

  @override
  void initState() {
    super.initState();
    for (final app in _upd.otherApps) {
      _appFocus[app.id] = FocusNode(debugLabel: 'InfoApp-${app.id}');
      _appFocus['${app.id}_del'] =
          FocusNode(debugLabel: 'InfoAppDel-${app.id}');
    }
    _init();
  }

  Future<void> _init() async {
    final id = await LicenseService.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
    await _loadLicense();
    await _upd.ensureInitialized();
    if (mounted) {
      _upd.checkForUpdate();
      _upd.fetchOtherAppsInfo();
      if (_backFocus.canRequestFocus) _backFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _backFocus.dispose();
    _keyFocus.dispose();
    _checkFocus.dispose();
    _primaryFocus.dispose();
    _secondaryFocus.dispose();
    for (final n in _appFocus.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLicense() async {
    final data = await LicenseService.fetchLicenseStatus();
    if (!mounted) return;
    if (data != null) {
      final status = (data['status'] ?? '') as String;
      setState(() {
        if (status == 'active') {
          _licenseChipKind = 0;
          _licenseChipText = 'Đã kích hoạt';
          if (data['plan'] == 'timed') {
            _isTimedActive = true;
            _isPermanentActive = false;
            final days = data['days_left'];
            _licensePlanText = days != null
                ? 'gói tháng — còn $days ngày'
                : 'gói tháng';
          } else {
            _isPermanentActive = true;
            _isTimedActive = false;
            _licensePlanText = 'gói vĩnh viễn';
          }
        } else if (status == 'trial') {
          _licenseChipKind = 1;
          final days = data['days_left'] ?? 30;
          _licenseChipText = 'Dùng thử — còn $days ngày';
          _licensePlanText = 'nhập key để kích hoạt đầy đủ';
        } else {
          _licenseChipKind = 2;
          _licenseChipText = 'Đã khoá';
          _licensePlanText = 'nhập key để mở khoá';
        }
      });
    } else {
      setState(() {
        _licenseChipKind = 1;
        _licenseChipText = 'Chưa rõ trạng thái';
        _licensePlanText = 'kiểm tra lại khi có mạng';
      });
    }
  }

  void _returnToHomeSidebar(BuildContext context) {
    final p = Provider.of<ButtonFocusProvider>(context, listen: false);
    p.buttonFocusedLabel = sidebarHomeOption;
    p.lastButtonFocusedLabel = sidebarHomeOption;
    Navigator.pop(context);
  }

  Future<void> _showKeyDialog() async {
    final controller = TextEditingController();
    final fieldFocus = FocusNode(debugLabel: 'KeyDialogField');
    final okFocus = FocusNode(debugLabel: 'KeyDialogOk');
    final closeFocus = FocusNode(debugLabel: 'KeyDialogClose');
    bool activating = false;
    String message = '';
    bool success = false;
    bool focusRequested = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!focusRequested) {
              focusRequested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (fieldFocus.canRequestFocus) fieldFocus.requestFocus();
              });
            }

            Future<void> submit() async {
              final key = controller.text.trim();
              if (key.isEmpty) {
                setDialogState(
                    () => message = 'Vui lòng nhập mã kích hoạt!');
                return;
              }
              setDialogState(() => activating = true);
              final result = await LicenseService.activateKey(key);
              if (!dialogContext.mounted) return;
              setDialogState(() {
                activating = false;
                message = (result['message'] ?? '') as String;
                success = result['status'] == 'success';
              });
              if (success) {
                await Future.delayed(const Duration(milliseconds: 700));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                _loadLicense();
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFF1B1B21),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _cardBorder),
              ),
              child: FocusTraversalGroup(
                child: Container(
                  width: 540,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isTimedActive
                            ? 'Nhập key gia hạn'
                            : 'Nhập key kích hoạt',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_isTimedActive) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Máy đang dùng gói tháng — key mới sẽ cộng thêm thời hạn vào gói hiện tại.',
                          style: TextStyle(
                              color: Color(0xFF9A9AA5), fontSize: 13.5),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        focusNode: fieldFocus,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nhập mã bản quyền...',
                          hintStyle:
                              const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF22222A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) {
                          if (!activating) submit();
                        },
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: TextStyle(
                            color: success
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _TvButton(
                            focusNode: closeFocus,
                            label: 'Đóng',
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                          ),
                          const SizedBox(width: 12),
                          _TvButton(
                            focusNode: okFocus,
                            label: activating ? 'Đang xử lý...' : 'Kích hoạt',
                            icon: Icons.key_rounded,
                            primary: true,
                            onPressed: activating ? null : submit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    fieldFocus.dispose();
    okFocus.dispose();
    closeFocus.dispose();
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}, ${two(t.day)}/${two(t.month)}/${t.year}';
  }

  String _mb(int bytes) =>
      (bytes / 1048576).toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final p = Provider.of<ButtonFocusProvider>(context, listen: false);
          p.buttonFocusedLabel = sidebarHomeOption;
          p.lastButtonFocusedLabel = sidebarHomeOption;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/welcome_bg.jpg', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(96, 30, 48, 30),
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin ứng dụng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Phiên bản, bản quyền và cập nhật — mọi thứ ở một chỗ.',
                      style: TextStyle(color: Color(0xFF9A9AA5), fontSize: 14),
                    ),
                    _buildHeaderCard(),
                    _buildUpdateCard(),
                    _buildOtherApps(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 20,
              child: _buildBackButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return AnimatedBuilder(
      animation: _backFocus,
      builder: (context, child) {
        final isFocused = _backFocus.hasFocus;
        return Focus(
          focusNode: _backFocus,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                SystemSound.play(SystemSoundType.click);
                _returnToHomeSidebar(context);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () {
              SystemSound.play(SystemSoundType.click);
              _returnToHomeSidebar(context);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFocused
                    ? _accent
                    : Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isFocused ? 2.5 : 1.8,
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                color: isFocused ? Colors.black : Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Thẻ đầu trang ----------

  Widget _buildHeaderCard() {
    final chipColors = [
      (const Color(0xFF10331C), const Color(0xFF4ADE80),
          const Color(0xFF3ECF6A)),
      (const Color(0xFF3A2A10), const Color(0xFFFBBF24),
          const Color(0xFFFBBF24)),
      (const Color(0xFF3A1414), const Color(0xFFF87171),
          const Color(0xFFF87171)),
    ];
    final c = chipColors[_licenseChipKind];
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B2B33)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Image.asset('assets/images/logo_banner.png',
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Truyền hình Như Ý',
                  style: TextStyle(
                    color: _nameRed,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Phiên bản hiện tại: ${_upd.currentVersion.isEmpty ? '...' : _upd.currentVersion}  •  Mã máy: ${_deviceId.isEmpty ? 'đang lấy...' : _deviceId}',
                  style: const TextStyle(
                      color: Color(0xFFB9B9C2), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Bản quyền:',
                        style: TextStyle(
                            color: Color(0xFFB9B9C2), fontSize: 14)),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.$1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: c.$3, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _licenseChipText,
                            style: TextStyle(
                              color: c.$2,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      _licensePlanText,
                      style: const TextStyle(
                          color: Color(0xFF83838E), fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isPermanentActive)
            _TvButton(
              focusNode: _keyFocus,
              label: _isTimedActive ? 'Nhập key gia hạn' : 'Nhập key kích hoạt',
              onPressed: _showKeyDialog,
            ),
        ],
      ),
    );
  }

  // ---------- Khối cập nhật ----------

  Widget _buildUpdateCard() {
    return AnimatedBuilder(
      animation: _upd,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF4A2626)),
          ),
          child: _updateCardContent(),
        );
      },
    );
  }

  Widget _badge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _updateTitle(Widget? badge, {Widget? extra}) {
    return Row(
      children: [
        const Text(
          '⬆ Cập nhật ứng dụng',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        if (badge != null) ...[const SizedBox(width: 12), badge],
        if (extra != null) ...[const SizedBox(width: 12), extra],
      ],
    );
  }

  Widget _updateCardContent() {
    switch (_upd.phase) {
      case UpdatePhase.checking:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(null),
            const SizedBox(height: 14),
            const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _accent),
                ),
                SizedBox(width: 12),
                Text('Đang kiểm tra bản mới...',
                    style:
                        TextStyle(color: Color(0xFFC9C9D1), fontSize: 15)),
              ],
            ),
          ],
        );

      case UpdatePhase.latest:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(_badge('MỚI NHẤT', const Color(0xFF1E7A38))),
            const SizedBox(height: 10),
            Text(
              '✓ Bạn đang dùng phiên bản mới nhất (${_upd.currentVersion}).',
              style: const TextStyle(color: Color(0xFFC9C9D1), fontSize: 15),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _TvButton(
                  focusNode: _checkFocus,
                  label: 'Kiểm tra lại',
                  icon: Icons.refresh_rounded,
                  onPressed: () => _upd.checkForUpdate(),
                ),
                const Spacer(),
                Text(
                  _upd.lastCheckAt != null
                      ? 'Kiểm tra lần cuối: ${_fmtTime(_upd.lastCheckAt)}'
                      : '',
                  style: const TextStyle(
                      color: Color(0xFF83838E), fontSize: 12.5),
                ),
              ],
            ),
          ],
        );

      case UpdatePhase.available:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(_badge('CÓ BẢN MỚI', _accent)),
            const SizedBox(height: 10),
            Text(
              'Phiên bản ${_upd.remoteVersion}${_upd.remoteSize.isNotEmpty ? ' — ${_upd.remoteSize}' : ''}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            ..._messageBullets(),
            const SizedBox(height: 16),
            Row(
              children: [
                _TvButton(
                  focusNode: _primaryFocus,
                  label: 'Tải bản cập nhật',
                  icon: Icons.download,
                  primary: true,
                  onPressed: () => _upd.startDownload(),
                ),
                const SizedBox(width: 12),
                _TvButton(
                  focusNode: _checkFocus,
                  label: 'Kiểm tra lại',
                  onPressed: () => _upd.checkForUpdate(),
                ),
                const Spacer(),
                Text(
                  _upd.lastCheckAt != null
                      ? 'Tự kiểm tra lúc mở trang này • ${_fmtTime(_upd.lastCheckAt)}'
                      : '',
                  style: const TextStyle(
                      color: Color(0xFF83838E), fontSize: 12.5),
                ),
              ],
            ),
          ],
        );

      case UpdatePhase.downloading:
        final pct = (_upd.progress * 100).toStringAsFixed(0);
        String detail = 'Đang tải bản ${_upd.remoteVersion}';
        if (_upd.totalBytes > 0) {
          detail +=
              ' — ${_mb(_upd.receivedBytes)} / ${_mb(_upd.totalBytes)} MB';
        }
        if (_upd.speedMBs > 0.05) {
          detail +=
              ' • tốc độ ${_upd.speedMBs.toStringAsFixed(1).replaceAll('.', ',')} MB/s';
          if (_upd.totalBytes > 0) {
            final remain =
                (_upd.totalBytes - _upd.receivedBytes) / 1048576;
            final eta = (remain / _upd.speedMBs).ceil();
            detail += ' • còn khoảng $eta giây';
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(null,
                extra: Text(
                  '$pct%',
                  style: const TextStyle(
                      color: _accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900),
                )),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _upd.totalBytes > 0 ? _upd.progress : null,
                minHeight: 12,
                backgroundColor: const Color(0xFF26262E),
                valueColor: const AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(detail,
                style:
                    const TextStyle(color: Color(0xFFC9C9D1), fontSize: 14)),
            const SizedBox(height: 13),
            Row(
              children: [
                _TvButton(
                  focusNode: _primaryFocus,
                  label: 'Huỷ tải',
                  onPressed: () => _upd.cancelDownload(),
                ),
                const Spacer(),
                const Text(
                  'Tải nền — cứ dùng app bình thường',
                  style: TextStyle(color: Color(0xFF83838E), fontSize: 12.5),
                ),
              ],
            ),
          ],
        );

      case UpdatePhase.downloaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(_badge(
                'ĐÃ TẢI VỀ — SẴN SÀNG CẬP NHẬT', const Color(0xFF8A6D1F))),
            const SizedBox(height: 10),
            Text(
              'Bản ${_upd.remoteVersion}${_upd.remoteSize.isNotEmpty ? ' (${_upd.remoteSize})' : ''} đã tải xong và đang chờ. Nhấn Cập nhật ngay khi bạn sẵn sàng — app không tự cài. Sau khi cập nhật xong, file đã tải sẽ tự xoá.',
              style: const TextStyle(
                  color: Color(0xFFC9C9D1), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _TvButton(
                  focusNode: _primaryFocus,
                  label: 'Cập nhật ngay',
                  icon: Icons.system_update,
                  primary: true,
                  onPressed: () => _upd.installDownloaded(),
                ),
                const SizedBox(width: 12),
                _TvButton(
                  focusNode: _secondaryFocus,
                  label: 'Xoá bản đã tải',
                  onPressed: () => _upd.deleteDownloaded(),
                ),
                const Spacer(),
                const Text(
                  'Để nguyên cũng được — không tốn thêm dung lượng lần sau',
                  style: TextStyle(color: Color(0xFF83838E), fontSize: 12.5),
                ),
              ],
            ),
          ],
        );

      case UpdatePhase.interrupted:
        final pctText = _upd.totalBytes > 0
            ? ' ở ${(_upd.receivedBytes / _upd.totalBytes * 100).toStringAsFixed(0)}%'
            : '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(
                _badge('TẢI BỊ GIÁN ĐOẠN', const Color(0xFF8C2B1F))),
            const SizedBox(height: 10),
            Text(
              '⚠ ${_upd.errorText.isNotEmpty ? _upd.errorText : 'Mất kết nối$pctText.'}',
              style: const TextStyle(color: Color(0xFFC9C9D1), fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _TvButton(
                  focusNode: _primaryFocus,
                  label: 'Tải tiếp',
                  icon: Icons.download,
                  primary: true,
                  onPressed: () => _upd.startDownload(),
                ),
                const SizedBox(width: 12),
                _TvButton(
                  focusNode: _secondaryFocus,
                  label: 'Tải lại từ đầu',
                  onPressed: () => _upd.startDownload(restart: true),
                ),
              ],
            ),
          ],
        );

      case UpdatePhase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _updateTitle(_badge('TẢI THẤT BẠI', const Color(0xFF8C2B1F))),
            const SizedBox(height: 10),
            Text(
              '⚠ ${_upd.errorText}',
              style: const TextStyle(color: Color(0xFFC9C9D1), fontSize: 14),
            ),
            const SizedBox(height: 14),
            _TvButton(
              focusNode: _primaryFocus,
              label: 'Tải lại',
              icon: Icons.refresh_rounded,
              primary: true,
              onPressed: () => _upd.startDownload(restart: true),
            ),
          ],
        );
    }
  }

  List<Widget> _messageBullets() {
    final msg = _upd.remoteMessage.trim();
    if (msg.isEmpty) return const [];
    final lines =
        msg.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return [
      const SizedBox(height: 8),
      ...lines.map(
        (line) => Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Text(
            '• $line',
            style: const TextStyle(color: Color(0xFFC9C9D1), fontSize: 14),
          ),
        ),
      ),
    ];
  }

  // ---------- Mục ứng dụng khác ----------

  Widget _buildOtherApps() {
    return AnimatedBuilder(
      animation: _upd,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            const Text(
              '⬇ Ứng dụng khác của Như Ý',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tải và cài đặt thêm các ứng dụng khác của Như Ý ngay trên máy này.',
              style: TextStyle(color: Color(0xFF9A9AA5), fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            // Mỗi ứng dụng một dòng riêng, thẻ chạy hết chiều ngang.
            for (int i = 0; i < _upd.otherApps.length; i++) ...[
              _otherAppCard(_upd.otherApps[i]),
              if (i < _upd.otherApps.length - 1)
                const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _otherAppCard(OtherApp app) {
    final color = Color(app.colorValue);
    String versionLine = app.subtitle;
    if (app.remoteVersion.isNotEmpty) {
      versionLine =
          '${app.subtitle} • v${app.remoteVersion}${app.remoteSize.isNotEmpty ? ' • ${app.remoteSize}' : ''}';
    }

    Widget action;
    switch (app.phase) {
      case OtherAppPhase.downloading:
        action = _TvButton(
          focusNode: _appFocus[app.id]!,
          label: '${(app.progress * 100).toStringAsFixed(0)}%',
          color: color,
        );
        break;
      case OtherAppPhase.downloaded:
        action = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TvButton(
              focusNode: _appFocus[app.id]!,
              label: 'Cài đặt',
              icon: Icons.install_mobile,
              color: color,
              onPressed: () => _upd.installOtherApp(app),
            ),
            const SizedBox(width: 10),
            _TvButton(
              focusNode: _appFocus['${app.id}_del']!,
              label: 'Xoá',
              icon: Icons.delete_outline_rounded,
              onPressed: () => _upd.deleteOtherApp(app),
            ),
          ],
        );
        break;
      case OtherAppPhase.failed:
        action = _TvButton(
          focusNode: _appFocus[app.id]!,
          label: 'Thử lại',
          icon: Icons.refresh_rounded,
          color: color,
          onPressed: () => _upd.downloadOtherApp(app),
        );
        break;
      case OtherAppPhase.loading:
      case OtherAppPhase.idle:
        action = _TvButton(
          focusNode: _appFocus[app.id]!,
          label: 'Đang lấy...',
          color: color,
        );
        break;
      case OtherAppPhase.ready:
        action = _TvButton(
          focusNode: _appFocus[app.id]!,
          label: 'Tải APK',
          icon: Icons.download,
          color: color,
          onPressed: () => _upd.downloadOtherApp(app),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFF2B2B33)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(app.logoAsset, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: TextStyle(
                    color: color,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  versionLine,
                  style: const TextStyle(
                      color: Color(0xFF9A9AA5), fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}

/// Nút bấm chuẩn TV cho trang Thông tin: viền trắng + sáng lên khi
/// được chọn bằng điều khiển, bấm được bằng OK/Enter/Space và chạm.
class _TvButton extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? color;

  const _TvButton({
    required this.focusNode,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? _accent;
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;
        final enabled = onPressed != null;
        final solid = primary || color != null;
        // Focus phải thật dễ nhận biết trên tivi: nút thường khi được
        // chọn sẽ đảo sang nền trắng chữ đen; nút màu/nút chính giữ
        // màu nhưng thêm viền trắng dày, phóng to nhẹ và đổ bóng.
        final Color bg = !enabled
            ? const Color(0xFF22222A)
            : isFocused && !solid
                ? Colors.white
                : solid
                    ? baseColor
                    : const Color(0xFF22222A);
        final Color fg = !enabled
            ? const Color(0xFF83838E)
            : isFocused && !solid
                ? Colors.black
                : Colors.white;
        return Focus(
          focusNode: focusNode,
          onFocusChange: (focused) {
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.35,
                duration: const Duration(milliseconds: 200),
              );
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && enabled) {
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                SystemSound.play(SystemSoundType.click);
                onPressed!.call();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: enabled
                ? () {
                    SystemSound.play(SystemSoundType.click);
                    onPressed!.call();
                  }
                : null,
            child: AnimatedScale(
              scale: isFocused && enabled ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: isFocused
                        ? Colors.white
                        : solid
                            ? Colors.transparent
                            : const Color(0xFF34343F),
                    width: isFocused ? 3 : 1.2,
                  ),
                  boxShadow: isFocused && enabled
                      ? [
                          const BoxShadow(
                            color: Colors.black54,
                            blurRadius: 16,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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
  }
}
