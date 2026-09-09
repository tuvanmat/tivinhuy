import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';

class MoviesController {
  static const String baseUrl = 'https://phimapi.com';

  static void _fixImageUrls(Map<String, dynamic> itemData, String domainImage) {
    if (domainImage.isEmpty) return;

    String thumbUrl = itemData['thumb_url'] ?? '';
    if (thumbUrl.isNotEmpty && !thumbUrl.startsWith('http')) {
      itemData['thumb_url'] = domainImage +
          (thumbUrl.startsWith('/') ? thumbUrl.substring(1) : thumbUrl);
    }

    String posterUrl = itemData['poster_url'] ?? '';
    if (posterUrl.isNotEmpty && !posterUrl.startsWith('http')) {
      itemData['poster_url'] = domainImage +
          (posterUrl.startsWith('/') ? posterUrl.substring(1) : posterUrl);
    }
  }

  // Lấy danh sách phim và bổ sung thông tin thực tế từ API chi tiết
  Future<List<MovieModel>> readTopMovies({
    int page = 1,
    String type = 'phim-moi',
  }) async {
    try {
      String url;

      if (type.contains('/')) {
        final parts = type.split('/');
        final category = parts[0];
        final slug = parts[1];
        url = '$baseUrl/v1/api/$category/$slug?page=$page';
      } else if (type == 'phim-moi') {
        url = '$baseUrl/danh-sach/phim-moi-cap-nhat?page=$page';
      } else {
        url = '$baseUrl/v1/api/danh-sach/$type?page=$page';
      }

      debugPrint('Đang gọi API danh sách: $url');
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;

        List<dynamic> items = [];
        String domainImage = '';

        if (data['items'] != null) {
          items = data['items'] as List<dynamic>;
          domainImage = data['APP_DOMAIN_CDN_IMAGE'] ?? 'https://phimimg.com/';
        } else if (data['data'] != null && data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          if (dataMap['items'] != null) {
            items = dataMap['items'] as List<dynamic>;
          }
          domainImage =
              dataMap['APP_DOMAIN_CDN_IMAGE'] ?? 'https://phimimg.com/';
        }

        if (!domainImage.endsWith('/')) {
          domainImage += '/';
        }

        List<MovieModel> basicMovies = items.map((dynamic item) {
          Map<String, dynamic> itemData =
              Map<String, dynamic>.from(item as Map<String, dynamic>);
          _fixImageUrls(itemData, domainImage);
          return MovieModel.fromJson(itemData);
        }).toList();

        // Tự động gọi ngầm API chi tiết từng phim để lấy thông số thực tế
        List<MovieModel> detailedMovies = await Future.wait(
          basicMovies.map((movie) async {
            if (movie.slug.isEmpty) return movie;
            try {
              final detailUrl = '$baseUrl/phim/${movie.slug}';
              final detailRes = await http
                  .get(Uri.parse(detailUrl))
                  .timeout(const Duration(seconds: 4));
              if (detailRes.statusCode == 200) {
                final detailData =
                    json.decode(detailRes.body) as Map<String, dynamic>;
                if (detailData['status'] == true &&
                    detailData['movie'] != null) {
                  final movieJson = detailData['movie'] as Map<String, dynamic>;

                  // Chỉ lấy đúng chất lượng thực tế từ API chi tiết (nếu không có thì để rỗng để ẩn nhãn)
                  String realQuality = '';
                  if (movieJson['quality'] != null &&
                      movieJson['quality'].toString().trim().isNotEmpty) {
                    realQuality = movieJson['quality'].toString().trim();
                  } else if (movieJson['resolution'] != null &&
                      movieJson['resolution'].toString().trim().isNotEmpty) {
                    realQuality = movieJson['resolution'].toString().trim();
                  }

                  String realTime = movie.time;
                  if (movieJson['time'] != null &&
                      movieJson['time'].toString().trim().isNotEmpty) {
                    realTime = movieJson['time'].toString().trim();
                  } else if (movieJson['episode_current'] != null &&
                      movieJson['episode_current']
                          .toString()
                          .trim()
                          .isNotEmpty) {
                    realTime = movieJson['episode_current'].toString().trim();
                  }

                  String realYear = '';
                  if (movieJson['year'] != null) {
                    realYear = movieJson['year'].toString().trim();
                  } else if (movieJson['publish_year'] != null) {
                    realYear = movieJson['publish_year'].toString().trim();
                  }

                  String realLanguage = '';
                  if (movieJson['language'] != null &&
                      movieJson['language'].toString().trim().isNotEmpty) {
                    realLanguage = movieJson['language'].toString().trim();
                  } else if (movieJson['lang'] != null &&
                      movieJson['lang'].toString().trim().isNotEmpty) {
                    realLanguage = movieJson['lang'].toString().trim();
                  }

                  return MovieModel(
                    id: movie.id,
                    title: movie.title,
                    slug: movie.slug,
                    horizontalPhoto: movie.horizontalPhoto,
                    verticalPhoto: movie.verticalPhoto,
                    description: movie.description,
                    url: movie.url,
                    quality:
                        realQuality, // Không còn gán cứng mặc định là FHD/HD nữa
                    time: realTime,
                    year: realYear,
                    language: realLanguage,
                    episodes: movie.episodes,
                  );
                }
              }
            } catch (_) {}
            return movie;
          }),
        );

        return detailedMovies;
      }
      return <MovieModel>[];
    } catch (e) {
      debugPrint('Lỗi tải danh sách phim ($type): $e');
      return <MovieModel>[];
    }
  }

  Future<List<MovieModel>> searchMovies(String keyword) async {
    if (keyword.trim().isEmpty) return <MovieModel>[];
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/v1/api/tim-kiem?keyword=$keyword'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        if (decodedBody == null || decodedBody is! Map<String, dynamic>) {
          return <MovieModel>[];
        }

        final Map<String, dynamic> data = decodedBody;
        List<dynamic> items = [];
        String domainImage = 'https://phimimg.com/';

        if (data['items'] != null && data['items'] is List) {
          items = data['items'] as List<dynamic>;
          domainImage = data['APP_DOMAIN_CDN_IMAGE'] ?? domainImage;
        } else if (data['data'] != null) {
          final responseData = data['data'];
          if (responseData is Map) {
            if (responseData['items'] != null &&
                responseData['items'] is List) {
              items = responseData['items'] as List<dynamic>;
            } else if (responseData['data'] != null &&
                responseData['data'] is List) {
              items = responseData['data'] as List<dynamic>;
            }
            domainImage = responseData['APP_DOMAIN_CDN_IMAGE'] ?? domainImage;
          } else if (responseData is List) {
            items = responseData;
          }
        }

        if (!domainImage.endsWith('/')) {
          domainImage += '/';
        }

        List<MovieModel> results = [];
        for (var item in items) {
          try {
            if (item is Map) {
              Map<String, dynamic> itemData =
                  Map<String, dynamic>.from(item as Map<String, dynamic>);
              _fixImageUrls(itemData, domainImage);
              results.add(MovieModel.fromJson(itemData));
            }
          } catch (_) {}
        }

        return results;
      }
      return <MovieModel>[];
    } catch (e) {
      debugPrint('Lỗi tìm kiếm phim: $e');
      return <MovieModel>[];
    }
  }

  static Future<MovieModel?> getMovieDetails(String slug) async {
    if (slug.isEmpty) return null;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/phim/$slug'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == true && data['movie'] != null) {
          final dynamic episodesData =
              data['episodes'] ?? data['movie']['episodes'];

          return MovieModel.fromDetailJson(
            data['movie'] as Map<String, dynamic>,
            episodesData,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Lỗi chi tiết phim: $e');
      return null;
    }
  }
}
