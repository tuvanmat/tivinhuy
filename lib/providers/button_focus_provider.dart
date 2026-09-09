import 'dart:math';

import 'package:flutter/material.dart';

class ButtonFocusProvider extends ChangeNotifier {
  String _buttonFocusedLabel = "";

  final seed = Random(DateTime.now().millisecondsSinceEpoch);

  String get buttonFocusedLabel => _buttonFocusedLabel;

  set buttonFocusedLabel(String value) {
    if (_buttonFocusedLabel == value) {
      return;
    }

    _buttonFocusedLabel = value;
    notifyListeners();
  }

  String _lastButtonFocusedLabel = "";

  String get lastButtonFocusedLabel => _lastButtonFocusedLabel;

  set lastButtonFocusedLabel(String value) {
    if (_lastButtonFocusedLabel == value) {
      return;
    }

    _lastButtonFocusedLabel = value;
    notifyListeners();
  }

  int getRandomNumber() {
    return seed.nextInt(100);
  }
}
