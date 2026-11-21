import 'package:flutter/material.dart';
import 'package:tv_flutter_app/utils/utils.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/welcome_bg.jpg',
      fit: BoxFit.cover,
      width: mqWidth(context, 100),
      height: mqHeigth(context, 100),
    );
  }
}
