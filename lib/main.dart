import 'package:flutter/material.dart';
import './pages/home_page.dart';

void main() {
  runApp(new MaterialApp(
    home: new HomePage(),
    theme: _kGalleryDarkTheme,
  ));
}

final ThemeData _kGalleryDarkTheme = new ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.blue,
);
