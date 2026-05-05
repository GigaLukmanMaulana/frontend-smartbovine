import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/auth_service.dart';

class DeviceMonitorScreen extends StatefulWidget {
  final Map<String, dynamic> perangkatData;

  const DeviceMonitorScreen({super.key, required this.perangkatData});

  @override
  State<DeviceMonitorScreen> createState() => _DeviceMonitorScreenState();
}

class _DeviceMonitorScreenState extends State<DeviceMonitorScreen> {
  // Hasil prediksi AI
  String _statusKesehatan = "Memuat...";
  String _statusAktivitas = "Memuat...";
  double _predictedSuhu = 0.0;

  StreamSubscription? _firebaseSubscription;
  Stream<DatabaseEvent>? _sensorStream;

  // Variabel sensor
  double _lastSuhu = 0.0;
  double _lastSuhuLingkungan = 0.0;
  double _lastLembap = 0.0;
  double _lastAccX = 0.0;
  double _lastAccY = 0.0;
  double _lastAccZ = 0.0;

  late DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    // Gunakan id_perangkat sebagai referensi node di Firebase
    String path = widget.perangkatData['id_perangkat'] ?? 'sapi_unknown';
    _dbRef = FirebaseDatabase.instance.ref(path);

    _sensorStream = _dbRef.onValue.asBroadcastStream();

    _firebaseSubscription = _sensorStream!.listen((event) {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      _lastSuhu            = (data['suhu'] ?? 0.0).toDouble();
      _lastSuhuLingkungan  = (data['suhu_lingkungan'] ?? 0.0).toDouble();
      _lastLembap          = (data['lembap'] ?? 0.0).toDouble();
      _lastAccX            = (data['acc_x'] ?? 0.0).toDouble();
      _lastAccY            = (data['acc_y'] ?? 0.0).toDouble();
      _lastAccZ            = (data['acc_z'] ?? 0.0).toDouble();

      _fetchAIPredict();
    });
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAIPredict() async {
    try {
      double suhuYangDikirim = _lastSuhu;

      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/predict'
          '?suhu=$_lastSuhu'
          '&suhu_lingkungan=$_lastSuhuLingkungan'
          '&lembap=$_lastLembap'
          '&acc_x=$_lastAccX'
          '&acc_y=$_lastAccY'
          '&acc_z=$_lastAccZ',
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _statusKesehatan = data['status_kesehatan'] ?? 'Tidak diketahui';
            _statusAktivitas = data['status_aktivitas'] ?? 'Tidak diketahui';
            _predictedSuhu   = suhuYangDikirim;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusKesehatan = "Gagal terhubung";
          _statusAktivitas = "Gagal terhubung";
        });
      }
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
    final sapi = widget.perangkatData['sapi'] ?? {};
    final namaSapi = sapi['nama_sapi'] ?? 'Sapi Tanpa Nama';
    final jenisKelamin = sapi['jenis_kelamin'] ?? '-';
    // Menyesuaikan id perangkat sebagai informasi tambahan di subtitle
    final idPerangkat = widget.perangkatData['id_perangkat'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Monitor $namaSapi',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
            return const Center(child: Text("Data sensor tidak ditemukan. Alat mungkin offline."));
          }

          final data = Map<String, dynamic>.from(dataValue as Map);

          double suhuTubuh = (data['suhu'] ?? 0.0).toDouble();
          double lembap    = (data['lembap'] ?? 0.0).toDouble();
          double accX      = (data['acc_x'] ?? 0.0).toDouble();
          double accY      = (data['acc_y'] ?? 0.0).toDouble();
          double accZ      = (data['acc_z'] ?? 0.0).toDouble();
          
          double latitude  = (data['latitude'] ?? 0.0).toDouble();
          double longitude = (data['longitude'] ?? 0.0).toDouble();

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
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFFE0E0E0),
                        child: Icon(Icons.pets, color: Colors.grey),
                      ),
                      title: Text(
                        namaSapi,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$jenisKelamin • Perangkat: $idPerangkat',
                        style: const TextStyle(fontSize: 12),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                      suhuTubuh == -99 ? 'Err' : '${suhuTubuh.toStringAsFixed(1)}°C',
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
                      latitude != 0.0 ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}' : 'Mencari Sinyal...',
                      Icons.location_on,
                      latitude != 0.0 ? Colors.green : Colors.grey,
                      waktuUpdate,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
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
}
