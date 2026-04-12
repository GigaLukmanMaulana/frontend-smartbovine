import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert'; // Untuk Base64 encoding
import 'package:http/http.dart' as http; // Untuk tembak API

class ScanFesesScreen extends StatefulWidget {
  const ScanFesesScreen({super.key});

  @override
  State<ScanFesesScreen> createState() => _ScanFesesScreenState();
}

class _ScanFesesScreenState extends State<ScanFesesScreen> {
  XFile? _imageFile;
  Uint8List? _webImage;
  final picker = ImagePicker();
  bool _isAnalyzing = false;
  
  // State untuk menampung hasil dari Roboflow
  String _resultTitle = "";
  String _resultDescription = "";
  bool _showResult = false;
  Color _resultColor = Colors.green;

  Future getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      var f = await pickedFile.readAsBytes();
      setState(() {
        _webImage = f;
        _imageFile = pickedFile;
        _showResult = false; 
      });
    }
  }

  // --- FUNGSI TEMBAK ROBOFLOW ---
  Future<void> _analyzeWithRoboflow() async {
    if (_webImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _showResult = false;
    });

    try {
      // 1. Convert gambar ke Base64 sesuai kebutuhan curl lu
      String base64Image = base64Encode(_webImage!);

      // 2. Tembak API Roboflow
      final response = await http.post(
        Uri.parse("https://serverless.roboflow.com/fesessapi/2?api_key=M5HKOA5obBXa63BviYLJ"),
        body: base64Image,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 3. Analisis Prediksi (Roboflow biasanya kasih list predictions)
        List predictions = data['predictions'] ?? [];

        if (predictions.isNotEmpty) {
          // Ambil prediksi dengan confidence tertinggi (biasanya urutan pertama)
          var topResult = predictions[0];
          String label = topResult['class']; // Contoh: 'sakit' atau 'sehat'
          double confidence = (topResult['confidence'] as double) * 100;

          setState(() {
            _resultTitle = "Hasil Deteksi: ${label.toUpperCase()}";
            _resultDescription = "Tingkat keyakinan AI sebesar ${confidence.toStringAsFixed(1)}%.";
            
            // Atur warna berdasarkan label
            if (label.toLowerCase().contains('sakit') || label.toLowerCase().contains('tidak sehat')) {
              _resultColor = Colors.red;
            } else {
              _resultColor = Colors.green;
            }
            _showResult = true;
          });
        } else {
          _setManualResult("Tidak Terdeteksi", "AI tidak menemukan objek feses yang jelas.", Colors.orange);
        }
      } else {
        _setManualResult("Server Error", "Gagal terhubung ke Roboflow (${response.statusCode})", Colors.grey);
      }
    } catch (e) {
      _setManualResult("Error", "Terjadi kesalahan: $e", Colors.grey);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _setManualResult(String title, String desc, Color color) {
    setState(() {
      _resultTitle = title;
      _resultDescription = desc;
      _resultColor = color;
      _showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E20)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Scan AI Roboflow', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Gunakan kamera untuk mendeteksi kondisi kesehatan sapi melalui sampel feses secara real-time.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
            
            // Area Upload
            GestureDetector(
              onTap: () => _showPicker(context),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: _webImage == null
                    ? _buildPlaceholder()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(_webImage!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 25),

            // Tombol Analisis
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _webImage == null || _isAnalyzing ? null : _analyzeWithRoboflow,
                icon: _isAnalyzing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics_outlined),
                label: Text(_isAnalyzing ? 'Menganalisis di Server...' : 'Mulai Analisis AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // HASIL DINAMIS
            if (_showResult) _buildResultBox(),
            
            const SizedBox(height: 40),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBox() {
  // Gunakan variabel lokal agar lebih aman (null-safety)
  final Color displayColor = _resultColor; 

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      // Tambahkan pengecekan atau default value
      color: displayColor.withOpacity(0.1), 
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: displayColor.withOpacity(0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: displayColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _resultTitle, 
                style: TextStyle(fontWeight: FontWeight.bold, color: displayColor)
              ),
              const SizedBox(height: 4),
              Text(
                _resultDescription, 
                style: const TextStyle(fontSize: 13, color: Colors.black87)
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 40, color: Color(0xFF1B5E20)),
        SizedBox(height: 10),
        Text('Pilih Gambar Feses', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
      ],
    );
  }

  Widget _buildFooter() {
    return const Row(
      children: [
        Icon(Icons.verified_user_outlined, size: 18, color: Colors.grey),
        SizedBox(width: 8),
        Expanded(child: Text('Model: Roboflow fesessapi/2. Hasil bersifat indikasi.', style: TextStyle(fontSize: 11, color: Colors.grey))),
      ],
    );
  }

  void _showPicker(context) {
    showModalBottomSheet(
      context: context,
      builder: (bc) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeri'), onTap: () { getImage(ImageSource.gallery); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Kamera'), onTap: () { getImage(ImageSource.camera); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }
}