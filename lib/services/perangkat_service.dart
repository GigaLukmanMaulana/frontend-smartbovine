import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PerangkatService {
  static String get baseUrl => AuthService.baseUrl;

  // 1. Ambil semua data perangkat
  static Future<List<dynamic>> getPerangkat() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/perangkat'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      print('Error getPerangkat: $e');
      return [];
    }
  }

  // 2. Tambah data perangkat
  static Future<Map<String, dynamic>> addPerangkat(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/perangkat'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error addPerangkat: $e');
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  // 3. Update data perangkat
  static Future<Map<String, dynamic>> updatePerangkat(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/perangkat/$id'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error updatePerangkat: $e');
      return {'success': false, 'message': 'Gagal terhubung ke server'};
    }
  }

  // 4. Hapus data perangkat
  static Future<bool> deletePerangkat(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/perangkat/$id'),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error deletePerangkat: $e');
      return false;
    }
  }
}
