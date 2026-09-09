import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Thêm import này
import 'package:tv_flutter_app/pages/home_page.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/providers/focused_movie_provider.dart';
import 'package:tv_flutter_app/providers/movies_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Hive cục bộ trên thiết bị Tivi
  await Hive.initFlutter();

  // Mở các box lưu trữ cho Yêu thích và Xem tiếp
  await Hive.openBox('favoritesBox');
  await Hive.openBox('historyBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ButtonFocusProvider()),
        ChangeNotifierProvider(create: (_) => MoviesProvider()),
        ChangeNotifierProvider(create: (_) => FocusedMovieProvider()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Phim Như Ý',
        home: HomePage(),
      ),
    );
  }
}
