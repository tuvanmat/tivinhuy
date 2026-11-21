import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChannelItem {
  final String name;
  final String logo;
  final String url;

  ChannelItem({required this.name, required this.logo, required this.url});
}

class ChannelService {
  static List<ChannelItem> _cachedChannels = [];
  static bool _isLoaded = false;

  static Future<List<ChannelItem>> fetchAllChannels() async {
    if (_isLoaded && _cachedChannels.isNotEmpty) {
      return _cachedChannels;
    }

    // Sử dụng nguồn chuẩn dành riêng cho Việt Nam để loại bỏ hoàn toàn kênh nước ngoài
    final sources = [
      'https://iptv-org.github.io/iptv/countries/vn.m3u',
    ];

    List<ChannelItem> tempChannels = [];
    Set<String> seenUrls = {};
    Set<String> seenNames = {};

    for (var url in sources) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final responseBody = utf8.decode(response.bodyBytes);

          // Sử dụng LineSplitter để tối ưu bộ nhớ, tránh tràn RAM trên TV
          final lines = const LineSplitter().convert(responseBody);

          String currentName = '';
          String currentLogo = '';

          for (var line in lines) {
            line = line.trim();
            if (line.startsWith('#EXTINF:')) {
              final commaIndex = line.lastIndexOf(',');
              if (commaIndex != -1) {
                currentName = line.substring(commaIndex + 1).trim();
              }
              if (line.contains('tvg-logo="')) {
                final start = line.indexOf('tvg-logo="') + 10;
                final end = line.indexOf('"', start);
                if (end != -1) {
                  currentLogo = line.substring(start, end);
                }
              }
            } else if (line.isNotEmpty && !line.startsWith('#')) {
              if (currentName.isNotEmpty) {
                final upperName = currentName.toUpperCase();

                if (!seenUrls.contains(line) &&
                    !seenNames.contains(upperName)) {
                  seenUrls.add(line);
                  seenNames.add(upperName);
                  tempChannels.add(ChannelItem(
                    name: currentName,
                    logo: currentLogo,
                    url: line,
                  ));
                }
              }
              currentName = '';
              currentLogo = '';
            }
          }
        }
      } catch (e) {
        debugPrint('Lỗi tải nguồn $url: $e');
      }
    }

    if (tempChannels.isNotEmpty) {
      _cachedChannels = tempChannels;
      _isLoaded = true;
    }

    return _cachedChannels;
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
