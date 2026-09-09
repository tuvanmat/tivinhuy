import 'package:flutter/material.dart';
import 'package:tv_flutter_app/controllers/movies_controller.dart';
import 'package:tv_flutter_app/models/movie_model.dart';

class MoviesProvider extends ChangeNotifier {
  final MoviesController _moviesController = MoviesController();

  List<MovieModel> _topMovies = [];
  List<MovieModel> get topMovies => _topMovies;

  bool _loadingTopMovies = false;
  bool get loadingTopMovies => _loadingTopMovies;

  bool _errorTopMovies = false;
  bool get errorTopMovies => _errorTopMovies;

  String _currentType = 'phim-moi';
  String get currentType => _currentType;

  // Các biến lưu trạng thái bộ lọc
  String _selectedGenre = 'Tất Cả';
  String get selectedGenre => _selectedGenre;

  String _selectedCountry = 'Tất Cả';
  String get selectedCountry => _selectedCountry;

  String _selectedYear = 'Tất Cả';
  String get selectedYear => _selectedYear;

  int _currentPage = 1;

  Future<List<MovieModel>> readTopMovies() async {
    _loadingTopMovies = true;
    _errorTopMovies = false;
    _currentPage = 1;
    notifyListeners();

    try {
      _topMovies = await _moviesController.readTopMovies(
          page: _currentPage, type: _currentType);
      _errorTopMovies = _topMovies.isEmpty;
      return _topMovies;
    } catch (e) {
      _errorTopMovies = true;
      return <MovieModel>[];
    } finally {
      _loadingTopMovies = false;
      notifyListeners();
    }
  }

  Future<void> fetchMovies({String type = 'phim-moi'}) async {
    _currentType = type;
    _selectedGenre = 'Tất Cả';
    _selectedCountry = 'Tất Cả';
    _selectedYear = 'Tất Cả';
    await readTopMovies();
  }

  // Hàm áp dụng bộ lọc chuẩn theo cấu trúc API của phimapi.com
  Future<void> applyFilter({
    required String genre,
    required String country,
    required String year,
  }) async {
    _selectedGenre = genre;
    _selectedCountry = country;
    _selectedYear = year;

    // Ưu tiên lọc theo Thể loại -> Quốc gia -> Năm (vì API chỉ nhận 1 tiêu chí chính trong 1 lần gọi)
    String targetType = 'phim-moi';

    if (genre != 'Tất Cả') {
      // Chuyển đổi tên hiển thị sang slug chuẩn của API thể loại
      String slug = _getGenreSlug(genre);
      targetType = 'the-loai/$slug';
    } else if (country != 'Tất Cả') {
      String slug = _getCountrySlug(country);
      targetType = 'quoc-gia/$slug';
    } else if (year != 'Tất Cả') {
      targetType = 'nam-phat-hanh/$year';
    }

    _currentType = targetType;
    await readTopMovies();
  }

  // Chuyển đổi tên tiếng Việt sang slug thể loại
  String _getGenreSlug(String name) {
    switch (name) {
      case 'Hành Động':
        return 'hanh-dong';
      case 'Phiêu Lưu':
        return 'phieu-luu';
      case 'Hoạt Hình':
        return 'hoat-hinh';
      case 'Phim Hài':
        return 'phim-hai';
      case 'Hình Sự':
        return 'hinh-su';
      case 'Tài Liệu':
        return 'tai-lieu';
      case 'Chính Kịch':
        return 'chinh-kich';
      case 'Gia Đình':
        return 'gia-dinh';
      case 'Giả Tưởng':
        return 'gia-tuong';
      case 'Lịch Sử':
        return 'lich-su';
      case 'Kinh Dị':
        return 'kinh-di';
      case 'Phim Nhạc':
        return 'phim-nhac';
      case 'Bí Ẩn':
        return 'bi-an';
      case 'Lãng Mạn':
        return 'lang-man';
      case 'Khoa Học Viễn Tưởng':
        return 'khoa-hoc-vien-tuong';
      case 'Gây Cấn':
        return 'gay-can';
      case 'Chiến Tranh':
        return 'chien-tranh';
      case 'Miền Tây':
        return 'mien-tay';
      case 'Cổ Trang':
        return 'co-trang';
      case 'Tâm Lý':
        return 'tam-ly';
      case 'Phim 18+':
        return 'phim-18';
      case 'Tình Cảm':
        return 'tinh-cam';
      default:
        return 'hanh-dong';
    }
  }

  // Chuyển đổi tên quốc gia sang slug
  String _getCountrySlug(String name) {
    switch (name) {
      case 'Âu Mỹ':
        return 'au-my';
      case 'Anh':
        return 'anh';
      case 'Trung Quốc':
        return 'trung-quoc';
      case 'Indonesia':
        return 'indonesia';
      case 'Việt Nam':
        return 'viet-nam';
      case 'Hàn Quốc':
        return 'han-quoc';
      case 'Nhật Bản':
        return 'nhat-ban';
      case 'Thái Lan':
        return 'thai-lan';
      case 'Đài Loan':
        return 'dai-loan';
      case 'Hồng Kông':
        return 'hong-kong';
      case 'Ấn Độ':
        return 'an-do';
      case 'Pháp':
        return 'phap';
      case 'Đức':
        return 'duc';
      case 'Canada':
        return 'canada';
      default:
        return 'quoc-gia-khac';
    }
  }

  Future<void> clearFilter() async {
    _selectedGenre = 'Tất Cả';
    _selectedCountry = 'Tất Cả';
    _selectedYear = 'Tất Cả';
    await fetchMovies(type: 'phim-moi');
  }

  Future<List<MovieModel>> loadMoreMovies() async {
    _currentPage++;
    try {
      final newMovies = await _moviesController.readTopMovies(
          page: _currentPage, type: _currentType);
      if (newMovies.isNotEmpty) {
        _topMovies.addAll(newMovies);
        notifyListeners();
      }
      return newMovies;
    } catch (e) {
      return <MovieModel>[];
    }
  }
}
