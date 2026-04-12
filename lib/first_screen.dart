import 'package:flutter/material.dart';
import 'fitur/dashboard.dart';
import 'services/auth_service.dart';

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  State<FirstScreen> createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // 1. Tambahkan Controller
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  // 2. Fungsi Login
  void _handleLogin() async {
    setState(() => _isLoading = true);

    final result = await _authService.login(
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      Navigator.pushReplacement(
        // Pakai replacement supaya gak bisa back ke login
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Bagian Header Hijau ---
            Container(
              height: MediaQuery.of(context).size.height * 0.4,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFB4EC7D), // Hijau muda atas
                    Color(0xFF8ED65E), // Hijau bawah
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons
                          .agriculture, // Ganti dengan image asset sapi kamu nanti
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SmartBovine',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    'Solusi Pemantauan Ternak Cerdas',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // --- Bagian Form Input ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                children: [
                  TextField(
                    controller: _emailController, // <--- Pasang controller
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: const Color(0xFFF1F4ED),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController, // <--- Pasang controller
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Kata Sandi',
                      filled: true,
                      fillColor: const Color(0xFFF1F4ED),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Tombol Masuk dengan Loading
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _handleLogin, // <--- Panggil fungsi login
                      icon: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.login),
                      label: Text(_isLoading ? 'Menghubungkan...' : 'Masuk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
