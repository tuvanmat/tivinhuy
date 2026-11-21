import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm import này để cấu hình hướng màn hình
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tv_flutter_app/pages/main_layout.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ép buộc toàn bộ ứng dụng chỉ chạy ở chế độ xoay ngang (Landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Hive.initFlutter();
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
      ],
      child: MaterialApp(
        title: 'Tivi Như Ý',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const MainLayout(),
      ),
    );
  }
}
