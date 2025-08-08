import 'package:blsample2/screens/LoginPage.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final Color pink = Color(0xFFFD3A73);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TindrConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.pink)
            .copyWith(primary: pink, secondary: pink),
        appBarTheme: AppBarTheme(backgroundColor: pink),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: pink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: Size(double.infinity, 50),
          ),
        ),
      ),
      home: LoginPage(),
    );
  }
}
