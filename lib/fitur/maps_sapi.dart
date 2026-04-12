import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/navbar.dart'; // Import navbar kamu
import 'scan_feses_screen.dart'; // Import halaman scan
import '../services/auth_service.dart';

class MapSapiScreen extends StatefulWidget {
  const MapSapiScreen({super.key});

  @override
  State<MapSapiScreen> createState() => _MapSapiScreenState();
}

class _MapSapiScreenState extends State<MapSapiScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  bool _isLoading = true;
  int _selectedIndex = 1; // Set ke 1 karena ini halaman Peta

  @override
  void initState() {
    super.initState();
    _fetchSapiLocations();
  }

  // AMBIL DATA DARI LARAVEL
  // 1. UPDATE WARNA MARKER JADI HIJAU
  Future<void> _fetchSapiLocations() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/sapi-locations'),
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        setState(() {
          _markers = data.map((sapi) {
            return Marker(
              point: LatLng(
                double.parse(sapi['lat'].toString()),
                double.parse(sapi['lng'].toString()),
              ),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => _showSapiDetail(sapi),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green, // UBAH KE HIJAU
                  size: 40,
                ),
              ),
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetch: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. UPDATE TAMPILAN POPUP (MODAL BOTTOM SHEET)
  void _showSapiDetail(Map sapi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Agar layout lebih fleksibel
      backgroundColor:
          Colors.transparent, // Transparan agar rounded corner kelihatan
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Garis kecil di atas modal
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Nama Sapi & Label Live
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Sapi #${sapi['id_sapi'] ?? '1'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Colors.green),
                      SizedBox(width: 5),
                      Text(
                        "LIVE",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Text(
              "Limousin Cross • Jantan • 2.5 Tahun",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Card Lokasi & Terakhir Update
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.location_on_outlined,
                    label: "LOKASI",
                    value:
                        "Kandang Utara (Lat: ${sapi['lat']}, Long: ${sapi['lng']})",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.access_time,
                    label: "TERAKHIR UPDATE",
                    value: "Baru saja",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Card Suhu & Status Kesehatan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8F5E9)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF00695C),
                    child: Icon(Icons.thermostat, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Suhu Tubuh",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        "${sapi['suhu'] ?? '38.5'}°C",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF00695C),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "Normal",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Tombol Lihat Detail
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Lihat Detail",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET TAMBAHAN UNTUK CARD KECIL
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Monitoring Lokasi Sapi",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Pindahkan tombol refresh ke sini agar FAB utama tetap untuk Scan
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00695C)),
            onPressed: _fetchSapiLocations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00695C)),
            )
          : FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-6.5715, 107.7587), // Koordinat Subang
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'SmartBovine_Map_App_v1_Development_(kontak_admin@smartbovine.com)',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),

      // TAMBAHKAN INI: Agar sama dengan Dashboard
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScanFesesScreen()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32), // Hijau tua konsisten
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt_outlined, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // TAMBAHKAN INI: Panggil Navbar yang sudah kamu pisah
      bottomNavigationBar: CustomNavbar(
        selectedIndex: 1, 
        onItemSelected: (index) {
          debugPrint("Pindah ke index: $index");
        },
      ),
    );
  }
}
