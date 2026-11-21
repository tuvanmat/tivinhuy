class EpisodeModel {
  final String name;
  final String slug;
  final String linkM3u8;
  final String linkEmbed; // Thêm trường dự phòng link embed
  final String serverName;

  EpisodeModel({
    required this.name,
    required this.slug,
    required this.linkM3u8,
    required this.linkEmbed,
    this.serverName = '',
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json,
      {String serverName = ''}) {
    String m3u8 = json['link_m3u8']?.toString() ?? '';
    if (m3u8.isNotEmpty && !m3u8.startsWith('http')) {
      m3u8 = 'https:$m3u8';
    }

    String embed = json['link_embed']?.toString() ?? '';
    if (embed.isNotEmpty && !embed.startsWith('http')) {
      embed = 'https:$embed';
    }

    return EpisodeModel(
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      linkM3u8: m3u8.isNotEmpty ? m3u8 : embed,
      linkEmbed: embed,
      serverName: serverName,
    );
  }
}

class MovieModel {
  final int id;
  final String title;
  final String slug;
  final String horizontalPhoto;
  final String verticalPhoto;
  final String description;
  final String url;
  final String quality;
  final String time;
  final String language;
  final String year;
  final String currentEpisode;
  final String category; // Trường Thể loại
  final String country; // Trường Quốc gia
  final List<EpisodeModel> episodes;

  MovieModel({
    this.id = 0,
    required this.title,
    required this.slug,
    required this.horizontalPhoto,
    required this.verticalPhoto,
    required this.description,
    required this.url,
    this.quality = '',
    this.time = '',
    this.language = '',
    this.year = '',
    this.currentEpisode = '',
    this.category = '',
    this.country = '',
    this.episodes = const [],
  });

  static final MovieModel empty = MovieModel(
    id: 0,
    title: '',
    slug: '',
    horizontalPhoto: '',
    verticalPhoto: '',
    description: '',
    url: '',
    quality: '',
    time: '',
    language: '',
    year: '',
    currentEpisode: '',
    category: '',
    country: '',
    episodes: const [],
  );

  static String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return 'https://phimimg.com/$path';
  }

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    // Bóc tách chất lượng thực tế từ JSON danh sách
    String extractedQuality = '';
    if (json['quality'] != null &&
        json['quality'].toString().trim().isNotEmpty) {
      extractedQuality = json['quality'].toString().trim();
    } else if (json['resolution'] != null &&
        json['resolution'].toString().trim().isNotEmpty) {
      extractedQuality = json['resolution'].toString().trim();
    } else {
      extractedQuality = 'HD';
    }

    String extractedTime = '';
    if (json['time'] != null && json['time'].toString().trim().isNotEmpty) {
      extractedTime = json['time'].toString().trim();
    } else if (json['current_episode'] != null &&
        json['current_episode'].toString().trim().isNotEmpty) {
      extractedTime = json['current_episode'].toString().trim();
    } else if (json['episode_current'] != null &&
        json['episode_current'].toString().trim().isNotEmpty) {
      extractedTime = json['episode_current'].toString().trim();
    }

    String extractedLang = '';
    if (json['language'] != null &&
        json['language'].toString().trim().isNotEmpty) {
      extractedLang = json['language'].toString().trim();
    } else if (json['lang'] != null &&
        json['lang'].toString().trim().isNotEmpty) {
      extractedLang = json['lang'].toString().trim();
    }

    // Bóc tách thể loại ở dạng danh sách hoặc chuỗi nếu có trong JSON danh sách
    String parsedCategory = '';
    if (json['category'] != null) {
      if (json['category'] is List) {
        List<String> catNames = [];
        for (var cat in json['category']) {
          if (cat is Map && cat['name'] != null) {
            catNames.add(cat['name'].toString());
          }
        }
        parsedCategory = catNames.join(', ');
      } else if (json['category'] is String) {
        parsedCategory = json['category'];
      }
    }

    // Bóc tách quốc gia ở dạng danh sách hoặc chuỗi nếu có trong JSON danh sách
    String parsedCountry = '';
    if (json['country'] != null) {
      if (json['country'] is List) {
        List<String> countryNames = [];
        for (var c in json['country']) {
          if (c is Map && c['name'] != null) {
            countryNames.add(c['name'].toString());
          }
        }
        parsedCountry = countryNames.join(', ');
      } else if (json['country'] is String) {
        parsedCountry = json['country'];
      }
    }

    return MovieModel(
      id: json['id'] is int ? json['id'] : 1,
      title: json['name'] ?? json['origin_name'] ?? 'Không có tiêu đề',
      slug: json['slug'] ?? '',
      horizontalPhoto: _getImageUrl(json['poster_url'] ?? json['thumb_url']),
      verticalPhoto: _getImageUrl(json['thumb_url'] ?? json['poster_url']),
      description: json['description'] ?? '',
      url: '',
      quality: extractedQuality,
      time: extractedTime,
      language: extractedLang,
      year: json['year']?.toString() ?? '',
      currentEpisode: json['current_episode'] ?? json['episode_current'] ?? '',
      category: parsedCategory,
      country: parsedCountry,
      episodes: const [],
    );
  }

  factory MovieModel.fromDetailJson(
      Map<String, dynamic> json, dynamic episodesJson) {
    List<EpisodeModel> parsedEpisodes = [];

    var targetEpisodesJson = episodesJson;
    if ((targetEpisodesJson == null ||
            (targetEpisodesJson is List && targetEpisodesJson.isEmpty)) &&
        json['episodes'] != null &&
        json['episodes'] is List) {
      targetEpisodesJson = json['episodes'];
    }

    if (targetEpisodesJson != null && targetEpisodesJson is List) {
      for (var server in targetEpisodesJson) {
        if (server is Map) {
          final String serverName =
              server['server_name']?.toString() ?? 'Server chính';
          final serverData = server['server_data'];
          if (serverData != null && serverData is List) {
            for (var ep in serverData) {
              if (ep is Map) {
                final episode = EpisodeModel.fromJson(
                  Map<String, dynamic>.from(ep),
                  serverName: serverName,
                );
                if (episode.linkM3u8.isNotEmpty) {
                  parsedEpisodes.add(episode);
                }
              }
            }
          }
        }
      }
    }

    String firstStreamUrl = '';
    if (parsedEpisodes.isNotEmpty) {
      firstStreamUrl = parsedEpisodes.first.linkM3u8;
    } else if (json['link_m3u8'] != null &&
        json['link_m3u8'].toString().isNotEmpty) {
      firstStreamUrl = json['link_m3u8'].toString();
      if (!firstStreamUrl.startsWith('http')) {
        firstStreamUrl = 'https:$firstStreamUrl';
      }
    } else if (json['link_embed'] != null &&
        json['link_embed'].toString().isNotEmpty) {
      firstStreamUrl = json['link_embed'].toString();
      if (!firstStreamUrl.startsWith('http')) {
        firstStreamUrl = 'https:$firstStreamUrl';
      }
    }

    String detailQuality = '';
    if (json['quality'] != null &&
        json['quality'].toString().trim().isNotEmpty) {
      detailQuality = json['quality'].toString().trim();
    } else if (json['resolution'] != null &&
        json['resolution'].toString().trim().isNotEmpty) {
      detailQuality = json['resolution'].toString().trim();
    } else {
      detailQuality = 'HD';
    }

    String detailTime = '';
    if (json['time'] != null && json['time'].toString().trim().isNotEmpty) {
      detailTime = json['time'].toString().trim();
    } else if (json['current_episode'] != null &&
        json['current_episode'].toString().trim().isNotEmpty) {
      detailTime = json['current_episode'].toString().trim();
    } else if (json['episode_current'] != null &&
        json['episode_current'].toString().trim().isNotEmpty) {
      detailTime = json['episode_current'].toString().trim();
    }

    String detailLang = json['language'] ?? json['lang'] ?? '';
    String detailYear = json['year']?.toString() ?? '';
    String detailCurrentEp =
        json['current_episode'] ?? json['episode_current'] ?? '';

    // Bóc tách Thể loại từ JSON chi tiết[cite: 18]
    String parsedCategory = '';
    if (json['category'] != null && json['category'] is List) {
      List<String> catNames = [];
      for (var cat in json['category']) {
        if (cat is Map && cat['name'] != null) {
          catNames.add(cat['name'].toString());
        }
      }
      parsedCategory = catNames.join(', ');
    }

    // Bóc tách Quốc gia từ JSON chi tiết[cite: 18]
    String parsedCountry = '';
    if (json['country'] != null && json['country'] is List) {
      List<String> countryNames = [];
      for (var c in json['country']) {
        if (c is Map && c['name'] != null) {
          countryNames.add(c['name'].toString());
        }
      }
      parsedCountry = countryNames.join(', ');
    }

    return MovieModel(
      id: 1,
      title: json['name'] ?? json['origin_name'] ?? 'Không có tiêu đề',
      slug: json['slug'] ?? '',
      horizontalPhoto: _getImageUrl(json['poster_url'] ?? json['thumb_url']),
      verticalPhoto: _getImageUrl(json['thumb_url'] ?? json['poster_url']),
      description: json['content'] ?? json['description'] ?? '',
      url: firstStreamUrl,
      quality: detailQuality,
      time: detailTime,
      language: detailLang,
      year: detailYear,
      currentEpisode: detailCurrentEp,
      category: parsedCategory, // Gán thể loại[cite: 18]
      country: parsedCountry, // Gán quốc gia[cite: 18]
      episodes: parsedEpisodes,
    );
  }
}
