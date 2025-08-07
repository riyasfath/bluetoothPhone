import 'package:flutter/material.dart';
import 'BluetoothSettingsScreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final greenColor = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: greenColor,
        appBarTheme: AppBarTheme(
          backgroundColor: greenColor,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final greenColor = Color(0xFF1DB954);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggingIn = false;

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoggingIn = true;
      });
      // Simulate a login delay
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _isLoggingIn = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BluetoothPage()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instagram-like logo text
              Text(
                'bluetooth bl',
                style: TextStyle(
                  fontFamily: 'Billabong',
                  fontSize: 48,
                  color: greenColor,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Phone number, username, or email',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter username/email' : null,
                    ),
                    SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Enter password' : null,
                    ),
                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoggingIn ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoggingIn
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Log In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
