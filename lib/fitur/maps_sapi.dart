import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../widgets/navbar.dart';
import 'scan_feses_screen.dart';

class MapSapiScreen extends StatefulWidget {
  const MapSapiScreen({super.key});

  @override
  State<MapSapiScreen> createState() => _MapSapiScreenState();
}

class _MapSapiScreenState extends State<MapSapiScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<CircleMarker> _geofenceCircles = [];
  bool _isLoading = true;
  int _selectedIndex = 1;

  // Geofencing: titik pusat & radius dari Firebase
  LatLng _centerPoint = const LatLng(-6.5715, 107.7587);
  double _radiusKm = 5.0;

  StreamSubscription? _firebaseSubscription;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    super.dispose();
  }

  // AMBIL DATA REAL-TIME DARI FIREBASE
  void _listenToFirebase() {
    _firebaseSubscription = _dbRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Marker> newMarkers = [];
        List<CircleMarker> newCircles = [];
        LatLng centerLatLng = _centerPoint;
        double currentRadius = _radiusKm;

        // =============================================
        // 1. BACA KONFIGURASI KANDANG DARI FIREBASE
        // =============================================
        if (data.containsKey('konfig_kandang')) {
          final konfig = data['konfig_kandang'] as Map;
          double? latPusat = double.tryParse(konfig['lat_pusat']?.toString() ?? '');
          double? lngPusat = double.tryParse(konfig['lng_pusat']?.toString() ?? '');
          double? radiusObj = double.tryParse(konfig['radius_km']?.toString() ?? '');

          if (latPusat != null && lngPusat != null) {
            centerLatLng = LatLng(latPusat, lngPusat);
          }
          if (radiusObj != null) {
            currentRadius = radiusObj;
          }
        }

        // =============================================
        // 2. GAMBAR LINGKARAN PAGAR (GEOFENCE)
        // =============================================
        newCircles.add(
          CircleMarker(
            point: centerLatLng,
            color: Colors.green.withOpacity(0.08),
            borderStrokeWidth: 2,
            borderColor: Colors.green.withOpacity(0.5),
            useRadiusInMeter: true,
            radius: currentRadius * 1000, // KM ke Meter
          ),
        );

        // Alat ukur jarak (Haversine)
        const Distance distanceCalc = Distance();

        // =============================================
        // 3. PROSES SETIAP SAPI
        // =============================================
        data.forEach((key, value) {
          if (key.toString().startsWith('sapi') && value is Map) {
            double? lat = double.tryParse(value['latitude']?.toString() ?? '');
            double? lng = double.tryParse(value['longitude']?.toString() ?? '');

            if (lat != null && lng != null) {
              LatLng posisiSapi = LatLng(lat, lng);

              // Hitung jarak sapi ke pusat kandang
              double jarakMeter = distanceCalc.as(LengthUnit.Meter, centerLatLng, posisiSapi);
              double jarakKm = jarakMeter / 1000;
              bool keluarPagar = jarakMeter > (currentRadius * 1000);

              newMarkers.add(
                Marker(
                  point: posisiSapi,
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () => _showSapiDetail({
                      'id_sapi': key.toString(),
                      'lat': lat.toString(),
                      'lng': lng.toString(),
                      'suhu': value['suhu']?.toString() ?? 'N/A',
                      'keluar_pagar': keluarPagar,
                      'jarak_km': jarakKm.toStringAsFixed(2),
                    }),
                    child: Icon(
                      Icons.location_on,
                      color: keluarPagar ? Colors.red : Colors.green,
                      size: 40,
                    ),
                  ),
                ),
              );
            }
          }
        });

        if (mounted) {
          setState(() {
            _markers = newMarkers;
            _geofenceCircles = newCircles;
            _centerPoint = centerLatLng;
            _radiusKm = currentRadius;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
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

            // PERINGATAN KELUAR PAGAR
            if (sapi['keluar_pagar'] == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "PERINGATAN: Keluar Pagar! (${sapi['jarak_km']} KM dari kandang)",
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
        actions: const [
          // Icon Live Streaming / Realtime Indicator
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
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
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00695C)),
            )
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centerPoint,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'SmartBovine_Map_App_v1_Development_(kontak_admin@smartbovine.com)',
                ),
                CircleLayer(circles: _geofenceCircles),
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
