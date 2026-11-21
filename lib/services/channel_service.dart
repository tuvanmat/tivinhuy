import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class ChannelItem {
  final String name;
  final String logo;
  final String tvgId;
  final List<String> urls;

  ChannelItem({
    required this.name,
    required this.logo,
    this.tvgId = '',
    required this.urls,
  });

  /// Link phát chính (nguồn đầu tiên) — giữ tương thích với code cũ.
  String get url => urls.isNotEmpty ? urls.first : '';

  Map<String, dynamic> toJson() => {
        'name': name,
        'logo': logo,
        'tvgId': tvgId,
        'urls': urls,
      };

  factory ChannelItem.fromJson(Map<String, dynamic> json) {
    return ChannelItem(
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      tvgId: json['tvgId']?.toString() ?? '',
      urls:
          (json['urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class ChannelService {
  static const String _cacheBoxName = 'channelsBox';
  static const String _cacheKey = 'mergedChannelsV1';

  static List<ChannelItem> _cachedChannels = [];
  static bool _isLoaded = false;

  // Nguồn 1: danh sách iptv-org (kho chính).
  // Nguồn 2: file dự phòng tự quản trên server — khi một kênh có thêm link ở
  // file này, app tự gộp thành nguồn phát dự phòng cho kênh đó. Sửa file trên
  // server là cập nhật được link, không cần phát hành lại app.
  static const List<String> _sources = [
    'https://iptv-org.github.io/iptv/countries/vn.m3u',
    'https://trongnga.io.vn/app/tivi/fallback-channels.m3u',
  ];

  /// Khoá gộp kênh: ưu tiên tvg-id (bỏ hậu tố chất lượng @SD/@HD),
  /// không có thì dùng tên đã chuẩn hoá (bỏ HD/FHD/4K, bỏ ngoặc).
  static String _mergeKey(String tvgId, String name) {
    if (tvgId.isNotEmpty) {
      return 'id:${tvgId.toLowerCase().split('@').first}';
    }
    var n = name.toUpperCase();
    n = n.replaceAll(
        RegExp(r'\b(HD|FHD|SD|4K|UHD|1080P|720P|576P|480P)\b'), '');
    n = n.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]\s*'), ' ');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return 'name:$n';
  }

  static ChannelItem _mergeTwo(ChannelItem a, ChannelItem b) {
    final urls = List<String>.from(a.urls);
    for (final u in b.urls) {
      if (!urls.contains(u)) urls.add(u);
    }
    return ChannelItem(
      name: a.name,
      logo: a.logo.isNotEmpty ? a.logo : b.logo,
      tvgId: a.tvgId.isNotEmpty ? a.tvgId : b.tvgId,
      urls: urls,
    );
  }

  static List<ChannelItem> _parseM3u(String body) {
    final Map<String, ChannelItem> byKey = {};
    final List<String> order = [];

    String currentName = '';
    String currentLogo = '';
    String currentId = '';

    for (var line in const LineSplitter().convert(body)) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1) {
          currentName = line.substring(commaIndex + 1).trim();
        }
        currentLogo = _extractAttr(line, 'tvg-logo');
        currentId = _extractAttr(line, 'tvg-id');
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (currentName.isNotEmpty) {
          final item = ChannelItem(
            name: currentName,
            logo: currentLogo,
            tvgId: currentId,
            urls: [line],
          );
          final key = _mergeKey(currentId, currentName);
          final existing = byKey[key];
          if (existing == null) {
            byKey[key] = item;
            order.add(key);
          } else {
            byKey[key] = _mergeTwo(existing, item);
          }
        }
        currentName = '';
        currentLogo = '';
        currentId = '';
      }
    }
    return order.map((k) => byKey[k]!).toList();
  }

  static String _extractAttr(String line, String attr) {
    final marker = '$attr="';
    if (!line.contains(marker)) return '';
    final start = line.indexOf(marker) + marker.length;
    final end = line.indexOf('"', start);
    if (end == -1) return '';
    return line.substring(start, end);
  }

  static Future<List<ChannelItem>> fetchAllChannels() async {
    if (_isLoaded && _cachedChannels.isNotEmpty) {
      return _cachedChannels;
    }

    final Map<String, ChannelItem> merged = {};
    final List<String> order = [];

    for (final source in _sources) {
      try {
        final response = await http
            .get(Uri.parse(source))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final items = _parseM3u(utf8.decode(response.bodyBytes));
          for (final item in items) {
            final key = _mergeKey(item.tvgId, item.name);
            final existing = merged[key];
            if (existing == null) {
              merged[key] = item;
              order.add(key);
            } else {
              merged[key] = _mergeTwo(existing, item);
            }
          }
        }
      } catch (e) {
        debugPrint('Lỗi tải nguồn $source: $e');
      }
    }

    var result =
        order.map((k) => merged[k]!).where((c) => c.urls.isNotEmpty).toList();

    if (result.isNotEmpty) {
      _cachedChannels = result;
      _isLoaded = true;
      _saveCache(result);
    } else {
      // Mất mạng hoặc mọi nguồn lỗi: dùng danh sách đã lưu trên máy.
      result = _loadCache();
      if (result.isNotEmpty) {
        _cachedChannels = result;
        _isLoaded = true;
      }
    }

    return _cachedChannels;
  }

  static void _saveCache(List<ChannelItem> items) {
    try {
      final box = Hive.box(_cacheBoxName);
      box.put(_cacheKey, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Lỗi lưu cache kênh: $e');
    }
  }

  static List<ChannelItem> _loadCache() {
    try {
      final box = Hive.box(_cacheBoxName);
      final raw = box.get(_cacheKey);
      if (raw is String && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => ChannelItem.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.urls.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Lỗi đọc cache kênh: $e');
    }
    return [];
  }

  static Future<List<ChannelItem>> getChannelsByType(String type) async {
    final all = await fetchAllChannels();
    return all.where((channel) {
      final upperName = channel.name.toUpperCase();
      if (type == 'VTV') {
        return upperName.contains('VTV');
      } else if (type == 'SCTV') {
        return upperName.contains('SCTV');
      } else if (type == 'HTV') {
        return upperName.contains('HTV');
      } else if (type == 'LOCAL') {
        return !upperName.contains('VTV') &&
            !upperName.contains('VTC') &&
            !upperName.contains('SCTV') &&
            !upperName.contains('HTV');
      }
      return false;
    }).toList();
  }
}
