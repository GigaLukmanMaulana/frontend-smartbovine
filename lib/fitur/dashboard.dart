import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/navbar.dart';
import 'scan_feses_screen.dart';
import 'notifikasi.dart';
import 'kelolaiot.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  // Hasil prediksi AI
  String _statusKesehatan = "Memuat...";
  String _statusAktivitas = "Memuat...";
  double _predictedSuhu = 0.0;

  // ✅ FIX 1: Hapus Timer, ganti dengan StreamSubscription
  StreamSubscription? _firebaseSubscription;
  Stream<DatabaseEvent>? _sensorStream;

  // Variabel sensor — ✅ FIX 2: Tambah suhu_lingkungan & lembap
  double _lastSuhu = 0.0;
  double _lastSuhuLingkungan = 0.0; // ← BARU
  double _lastLembap = 0.0;         // ← BARU
  double _lastAccX = 0.0;
  double _lastAccY = 0.0;
  double _lastAccZ = 0.0;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("sapi_1");

  @override
  void initState() {
    super.initState();

    // Simpan reference stream agar StreamBuilder tidak selalu mereset subskripsi setiap kali setState dipanggil.
    // Karena kita listen() di dua tempat (disini dan di StreamBuilder), kita wajib jadikan Broadcast Stream.
    _sensorStream = _dbRef.onValue.asBroadcastStream();

    // ✅ FIX 1: Panggil AI setiap kali data Firebase berubah (event-driven)
    _firebaseSubscription = _sensorStream!.listen((event) {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // ✅ FIX 2: Simpan semua data sensor termasuk suhu_lingkungan & lembap
      _lastSuhu            = (data['suhu'] ?? 0.0).toDouble();
      _lastSuhuLingkungan  = (data['suhu_lingkungan'] ?? 0.0).toDouble();
      _lastLembap          = (data['lembap'] ?? 0.0).toDouble();
      _lastAccX            = (data['acc_x'] ?? 0.0).toDouble();
      _lastAccY            = (data['acc_y'] ?? 0.0).toDouble();
      _lastAccZ            = (data['acc_z'] ?? 0.0).toDouble();

      // Panggil AI setiap ada data baru dari Firebase
      _fetchAIPredict();
    });
  }

  @override
  void dispose() {
    // ✅ FIX 1: Cancel subscription saat widget di-dispose
    _firebaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAIPredict() async {
    try {
      double suhuYangDikirim = _lastSuhu;

      // ✅ FIX 2: Kirim semua data sensor (tidak ada lagi yang dummy)
      final response = await http.get(
        Uri.parse(
          'http://192.168.18.102:8000/api/predict'
          '?suhu=$_lastSuhu'
          '&suhu_lingkungan=$_lastSuhuLingkungan'
          '&lembap=$_lastLembap'
          '&acc_x=$_lastAccX'
          '&acc_y=$_lastAccY'
          '&acc_z=$_lastAccZ',
        ),
      ).timeout(const Duration(seconds: 5)); // ✅ Timeout diperkecil dari 20 → 5 detik

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _statusKesehatan = data['status_kesehatan'] ?? 'Tidak diketahui';
          _statusAktivitas = data['status_aktivitas'] ?? 'Tidak diketahui';
          _predictedSuhu   = suhuYangDikirim;
        });
      }
    } catch (e) {
      setState(() {
        _statusKesehatan = "Gagal terhubung";
        _statusAktivitas = "Gagal terhubung";
      });
      debugPrint('Error fetch AI: $e');
    }
  }

  Color _getStatusColor() {
    switch (_statusKesehatan) {
      case 'Sehat':
        return Colors.green;
      case 'Heat Stress':
        return Colors.orange;
      case 'Sakit':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_statusKesehatan) {
      case 'Sehat':
        return Icons.check_circle;
      case 'Heat Stress':
        return Icons.thermostat;
      case 'Sakit':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusMessage() {
    switch (_statusKesehatan) {
      case 'Sehat':
        return 'Kondisi sapi optimal. Analisis AI menunjukkan tanda vital stabil.';
      case 'Heat Stress':
        return 'Peringatan! Sapi mengalami heat stress. Pastikan sirkulasi udara kandang baik.';
      case 'Sakit':
        return 'Peringatan! Sapi terdeteksi sakit. Segera hubungi dokter hewan.';
      default:
        return 'Menghubungkan ke server AI...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.black87),
        title: const Text(
          'SmartBovine',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotifikasiScreen(
                    currentStatus: _statusKesehatan,
                    currentSuhu: _predictedSuhu,
                  ),
                ),
              );
            },
            icon: const Badge(
              label: Text('1'),
              child: Icon(Icons.notifications_none, color: Colors.black87),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFF00796B),
              child: Text('J', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _sensorStream,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final Object? dataValue = snapshot.data?.snapshot.value;
          if (dataValue == null) {
            return const Center(child: Text("Data sensor tidak ditemukan"));
          }

          final data = Map<String, dynamic>.from(dataValue as Map);

          double suhuTubuh = (data['suhu'] ?? 0.0).toDouble();
          double lembap    = (data['lembap'] ?? 0.0).toDouble();
          double accX      = (data['acc_x'] ?? 0.0).toDouble();
          double accY      = (data['acc_y'] ?? 0.0).toDouble();
          double accZ      = (data['acc_z'] ?? 0.0).toDouble();

          String waktuUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
          Color statusColor  = _getStatusColor();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Card Profil Sapi dengan Expansion MPU ---
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFFE0E0E0),
                        child: Icon(Icons.pets, color: Colors.grey),
                      ),
                      title: const Text(
                        'Sapi #1',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Jantan • Kandang Blok A',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Akselerometer (MPU6050)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    "Update: $waktuUpdate",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMpuValue("X", accX),
                                  _buildMpuValue("Y", accY),
                                  _buildMpuValue("Z", accZ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Banner Status dari AI ---
                _buildStatusBanner(
                  _statusKesehatan,
                  statusColor,
                  _getStatusIcon(),
                  _getStatusMessage(),
                  waktuUpdate,
                ),
                const SizedBox(height: 12),



                // --- Grid Monitoring ---
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildInfoCard(
                      'Suhu Tubuh',
                      suhuTubuh == -99
                          ? 'Err'
                          : '${suhuTubuh.toStringAsFixed(1)}°C',
                      Icons.thermostat,
                      suhuTubuh > 39.5 ? Colors.red : Colors.orange,
                      waktuUpdate,
                    ),
                    _buildInfoCard(
                      'Lembap Kandang',
                      '${lembap.toStringAsFixed(1)}%',
                      Icons.cloud_outlined,
                      Colors.blue,
                      waktuUpdate,
                    ),
                    _buildInfoCard(
                      'Tingkat Aktivitas',
                      _statusAktivitas,
                      _statusAktivitas.contains('Aktif') ? Icons.directions_run : Icons.bedtime_outlined,
                      Colors.purple,
                      waktuUpdate,
                    ),
                    _buildInfoCard(
                      'Status GPS',
                      data['lat'] != 0 ? 'Locked' : 'No Signal',
                      Icons.location_on,
                      data['lat'] != 0 ? Colors.green : Colors.grey,
                      waktuUpdate,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Tindakan Cepat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _buildActionButton('Riwayat', Icons.history, Colors.teal),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      'Notifikasi',
                      Icons.notifications_none,
                      Colors.red,
                      isRed: true,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScanFesesScreen()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt_outlined, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomNavbar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const KelolaIotScreen()),
            ).then((_) {
              setState(() {
                _selectedIndex = 0;
              });
            });
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildStatusBanner(
    String status,
    Color color,
    IconData icon,
    String message,
    String waktu,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status Kesehatan: $status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      waktu,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                Text(
                  message,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    String waktu,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 20),
                Text(
                  waktu,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMpuValue(String axis, double value) {
    return Column(
      children: [
        Text(
          axis,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4ED),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color, {
    bool isRed = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isRed ? const Color(0xFFFFF1F0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRed ? Colors.red.withOpacity(0.1) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isRed ? Colors.red : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isRed ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
