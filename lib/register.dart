import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:si_kasir/login.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final Color customBlue = const Color(0xFF133E87);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Daftar Akun",
          style: TextStyle(
            color: customBlue,
            fontWeight: FontWeight.w600,
            fontSize: screenWidth * 0.060, // Ukuran font responsif
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: customBlue,
            size: screenWidth * 0.08, // Ukuran ikon responsif
          ),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04, vertical: screenHeight * 0.02),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/icons/register.png',
                  height: isPortrait ? screenHeight * 0.3 : screenHeight * 0.5,
                  width: screenWidth * 0.8,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: screenHeight * 0.03),
              _buildTextField(
                context,
                controller: _emailController,
                focusNode: _emailFocusNode,
                label: "Email",
                hint: "Masukkan Email",
                icon: Icons.email,
                isPassword: false,
              ),
              SizedBox(height: screenHeight * 0.02),
              _buildTextField(
                context,
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: "Kata Sandi",
                hint: "Masukkan Kata Sandi",
                icon: Icons.lock,
                isPassword: true,
                isVisible: _isPasswordVisible,
                onVisibilityChanged: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              SizedBox(height: screenHeight * 0.02),
              _buildTextField(
                context,
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                label: "Konfirmasi Kata Sandi",
                hint: "Masukkan Kata Sandi",
                icon: Icons.lock,
                isPassword: true,
                isVisible: _isConfirmPasswordVisible,
                onVisibilityChanged: () => setState(() =>
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
              ),
              SizedBox(height: screenHeight * 0.04),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: customBlue,
                  minimumSize: Size(double.infinity, screenHeight * 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.02),
                  ),
                ),
                child: Text(
                  "Daftar",
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword ? !isVisible : false,
      style: TextStyle(fontSize: screenWidth * 0.035),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.black,
          fontSize: screenWidth * 0.035,
        ),
        hintStyle: TextStyle(fontSize: screenWidth * 0.035),
        prefixIcon: Icon(icon, size: screenWidth * 0.06),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  size: screenWidth * 0.06,
                ),
                onPressed: onVisibilityChanged,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.02),
          borderSide: BorderSide(
            color: focusNode.hasFocus ? customBlue : Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.02),
          borderSide: BorderSide(color: customBlue, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.04,
          horizontal: screenWidth * 0.03,
        ),
      ),
    );
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showAlert("Error", "Harap diisi terlebih dahulu.");
      return;
    }

    if (password != confirmPassword) {
      _showAlert("Error", "Password dan Konfirmasi Password tidak cocok.");
      return;
    }

    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      _showAlert("Berhasil", "Akun berhasil dibuat.", navigateToLogin: true);
    } on FirebaseAuthException catch (e) {
      _showAlert("Error", e.message ?? "Terjadi kesalahan.");
    }
  }

  void _showAlert(String title, String message,
      {bool navigateToLogin = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (navigateToLogin) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: customBlue,
            ),
            child: Text("OK"),
          )
        ],
      ),
    );
  }
}