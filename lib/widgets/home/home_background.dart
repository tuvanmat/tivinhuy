import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/models/movie_model.dart';
import 'package:tv_flutter_app/providers/focused_movie_provider.dart';
import 'package:tv_flutter_app/utils/utils.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<FocusedMovieProvider, MovieModel>(
      selector: (context, focusedMovieProvider) =>
          focusedMovieProvider.focusedMovie,
      builder: (context, focusedMovie, _) {
        // Nếu chưa chọn phim nào (id == 0), hiển thị ảnh nền mặc định từ assets
        if (focusedMovie.id == 0 || focusedMovie.horizontalPhoto.isEmpty) {
          return Image.asset(
            'assets/images/welcome_bg.jpg',
            fit: BoxFit.cover,
            width: mqWidth(context, 100),
            height: mqHeigth(context, 100),
          );
        } else {
          // Khi đã có phim được focus, hiển thị ảnh nền động của phim qua NetworkImage
          return Image.network(
            focusedMovie.horizontalPhoto,
            fit: BoxFit.cover,
            width: mqWidth(context, 100),
            height: mqHeigth(context, 100),
            errorBuilder: (context, error, stackTrace) {
              // Fallback về ảnh mặc định nếu mạng lỗi hoặc link ảnh hỏng
              return Image.asset(
                'assets/images/welcome_bg.jpg',
                fit: BoxFit.cover,
                width: mqWidth(context, 100),
                height: mqHeigth(context, 100),
              );
            },
          );
        }
      },
    );
  }
}
