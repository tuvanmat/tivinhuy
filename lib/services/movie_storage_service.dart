import 'package:hive_flutter/hive_flutter.dart';
import 'package:tv_flutter_app/models/movie_model.dart';

class MovieStorageService {
  static const String _favoritesBoxName = 'favoritesBox';
  static const String _historyBoxName = 'historyBox';

  // --- QUẢN LÝ YÊU THÍCH ---
  static Box get _favBox => Hive.box(_favoritesBoxName);

  static Future<void> toggleFavorite(MovieModel movie) async {
    if (isFavorite(movie.slug)) {
      await _favBox.delete(movie.slug);
    } else {
      await _favBox.put(movie.slug, {
        'name': movie.title,
        'origin_name': movie.title,
        'title': movie.title,
        'slug': movie.slug,
        'thumb_url': movie.verticalPhoto,
        'poster_url': movie.horizontalPhoto,
        'quality': movie.quality,
        'time': movie.time,
        'year': movie.year,
        'language': movie.language,
        'description': movie.description,
      });
    }
  }

  static bool isFavorite(String slug) {
    return _favBox.containsKey(slug);
  }

  static List<MovieModel> getFavoriteMovies() {
    final values = _favBox.values;
    List<MovieModel> movies = [];
    for (var item in values) {
      if (item is Map) {
        movies.add(MovieModel.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return movies;
  }

  // --- QUẢN LÝ XEM TIẾP (LỊCH SỬ) ---
  static Box get _histBox => Hive.box(_historyBoxName);

  static Future<void> saveWatchProgress({
    required MovieModel movie,
    required int episodeIndex,
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    await _histBox.put(movie.slug, {
      'name': movie.title,
      'origin_name': movie.title,
      'title': movie.title,
      'slug': movie.slug,
      'thumb_url': movie.verticalPhoto,
      'poster_url': movie.horizontalPhoto,
      'quality': movie.quality,
      'time': movie.time,
      'year': movie.year,
      'language': movie.language,
      'description': movie.description,
      'episodeIndex': episodeIndex,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Map<String, dynamic>? getWatchProgress(String slug) {
    final data = _histBox.get(slug);
    if (data != null && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static List<Map<String, dynamic>> getContinueWatchingList() {
    final values = _histBox.values.toList();
    values.sort((a, b) => (b['updatedAt'] ?? 0).compareTo(a['updatedAt'] ?? 0));

    List<Map<String, dynamic>> list = [];
    for (var item in values) {
      if (item is Map) {
        list.add(Map<String, dynamic>.from(item));
      }
    }
    return list;
  }

  // [Đã bổ sung] Hàm xóa tiến trình xem của một phim khỏi lịch sử
  static Future<void> removeWatchProgress(String slug) async {
    if (_histBox.containsKey(slug)) {
      await _histBox.delete(slug);
    }
  }
}
