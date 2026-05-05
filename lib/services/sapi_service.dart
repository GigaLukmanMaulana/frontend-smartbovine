import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SapiService {
  static String get baseUrl => AuthService.baseUrl;

  // 1. Ambil semua data sapi
  static Future<List<dynamic>> getSapi() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sapi'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      print('Error getSapi: $e');
      return [];
    }
  }

  // 2. Tambah data sapi
  static Future<Map<String, dynamic>> addSapi(Map<String, dynamic> sapiData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sapi'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(sapiData),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Error addSapi: $e');
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  // 3. Hapus data sapi
  static Future<bool> deleteSapi(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sapi/$id'),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleteSapi: $e');
      return false;
    }
  }
}
