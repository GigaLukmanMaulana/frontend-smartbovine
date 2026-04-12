import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Ganti IP ini sesuai IP Laptop kamu (Satu Wi-Fi)
  static const String baseUrl = "http://192.168.18.102:8000/api"; //Kalau pakai HP bisa diganti ip laptop

  // 2. Gunakan static agar bisa dipanggil AuthService.saveSensorData(...)
  static Future<bool> saveSensorData(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/simpan-sensor"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ [MySQL] Berhasil: ${response.statusCode}");
        return true;
      } else {
        print("❌ [MySQL] Gagal: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("🚨 [MySQL] ERROR KONEKSI: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Simpan token ke HP agar tidak perlu login ulang
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", data["token"]);
        await prefs.setString("nama", data["data"]["nama_lengkap"]);

        return {"success": true, "message": "Selamat datang!"};
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Email atau password salah",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Gagal terhubung ke server: $e"};
    }
  }
}
