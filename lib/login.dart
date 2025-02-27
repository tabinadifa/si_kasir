import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:si_kasir/dashboard.dart';
import 'package:si_kasir/register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert("Error", "Harap isi email dan kata sandi.");
      return;
    }

    if (!_isValidEmail(email)) {
      _showAlert("Error", "Format email tidak valid.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ignore: unused_local_variable
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Simpan status login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);

      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getErrorMessage(e);
      _showAlert("Login Gagal", errorMessage);
    } catch (e) {
      _showAlert("Error", "Terjadi kesalahan tidak terduga.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Pengguna tidak ditemukan';
      case 'wrong-password':
        return 'Kata sandi salah';
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan';
      default:
        return 'Login gagal. Silakan coba lagi.';
    }
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      _showAlert("Error", "Masukkan email yang valid untuk reset kata sandi.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showAlert("Berhasil", "Email reset kata sandi telah dikirim.");
    } catch (e) {
      _showAlert("Error", "Gagal mengirim email reset kata sandi.");
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color customBlue = Color(0xFF133E87);
    final Size screenSize = MediaQuery.of(context).size;
    final double paddingHorizontal = screenSize.width * 0.05;
    final double paddingVertical = screenSize.height * 0.02;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: paddingHorizontal,
          vertical: paddingVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: screenSize.height * 0.1),
            Center(
              child: Image.asset(
                'assets/icons/login.png',
                height: screenSize.height * 0.25,
                width: screenSize.width * 0.5,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: screenSize.height * 0.03),
            Text(
              "Selamat Datang di Si Kasir!",
              style: TextStyle(
                fontSize: screenSize.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenSize.height * 0.03),
            TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "Masukkan Email",
                labelStyle: const TextStyle(color: Colors.black),
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _emailFocusNode.hasFocus ? customBlue : Colors.grey,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: customBlue),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.02,
                  horizontal: screenSize.width * 0.03,
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.02),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Kata Sandi",
                hintText: "Masukkan kata sandi",
                labelStyle: const TextStyle(color: Colors.black),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        _passwordFocusNode.hasFocus ? customBlue : Colors.grey,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: customBlue),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: screenSize.height * 0.02,
                  horizontal: screenSize.width * 0.03,
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.02),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetPassword,
                child: const Text(
                  "Lupa Kata Sandi?",
                  style: TextStyle(color: customBlue),
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.03),
            _isLoading
                ? CircularProgressIndicator(color: customBlue)
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: customBlue,
                      minimumSize: Size(
                        double.infinity,
                        screenSize.height * 0.05,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(screenSize.width * 0.02),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: screenSize.height * 0.01,
                      ),
                    ),
                    child: Text(
                      "Masuk",
                      style: TextStyle(
                        fontSize: screenSize.width * 0.045,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            SizedBox(height: screenSize.height * 0.03),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Belum punya akun? "),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Daftar",
                    style: TextStyle(color: customBlue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
