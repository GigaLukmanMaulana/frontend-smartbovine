import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotifikasiScreen extends StatefulWidget {
  final String? currentStatus;
  final double? currentSuhu;

  const NotifikasiScreen({
    super.key,
    this.currentStatus,
    this.currentSuhu,
  });

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  final DatabaseReference _notifRef = FirebaseDatabase.instance.ref('notifikasi');

  void _hapusSemuaNotifikasi() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua?'),
        content: const Text('Semua riwayat peringatan akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _notifRef.remove();
              Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp.toString()));
      Duration diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'BARU SAJA';
      if (diff.inMinutes < 60) return '${diff.inMinutes} MENIT LALU';
      if (diff.inHours < 24) return '${diff.inHours} JAM LALU';
      if (diff.inDays == 1) return 'KEMARIN';
      return '${diff.inDays} HARI LALU';
    } catch (e) {
      return 'BARU SAJA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Peringatan',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _hapusSemuaNotifikasi,
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _notifRef.orderByChild('timestamp').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> notifList = [];

          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value;
            if (data is Map) {
              data.forEach((key, value) {
                if (value is Map) {
                  final item = Map<String, dynamic>.from(value);
                  item['key'] = key;
                  notifList.add(item);
                }
              });
            }
          }

          // Urutkan dari yang terbaru
          notifList.sort((a, b) {
            int tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
            int tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
            return tsB.compareTo(tsA);
          });

          // Pisahkan mendesak (< 1 jam) dan history (> 1 jam)
          List<Map<String, dynamic>> mendesak = [];
          List<Map<String, dynamic>> history = [];

          for (var item in notifList) {
            int ts = int.tryParse(item['timestamp']?.toString() ?? '0') ?? 0;
            Duration diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
            if (diff.inHours < 1) {
              mendesak.add(item);
            } else {
              history.add(item);
            }
          }

          if (notifList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tidak ada peringatan', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Semua sapi dalam kondisi sehat 🐄', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mendesak.isNotEmpty) ...[
                  const Text(
                    'MENDESAK',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...mendesak.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildNotificationCard(
                      _getTitle(item['status']),
                      _getDescription(item),
                      _formatTimestamp(item['timestamp']),
                    ),
                  )),
                  const SizedBox(height: 8),
                ],

                if (history.isNotEmpty) ...[
                  const Text(
                    'HISTORY PERINGATAN',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...history.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildNotificationCard(
                      _getTitle(item['status']),
                      _getDescription(item),
                      _formatTimestamp(item['timestamp']),
                    ),
                  )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _getTitle(String? status) {
    if (status == 'Heat Stress') return 'Indikasi Heat Stress';
    return 'Indikasi Demam';
  }

  String _getDescription(Map<String, dynamic> item) {
    String namaSapi = item['nama_sapi'] ?? item['sapi_id'] ?? 'Sapi';
    double suhu = double.tryParse(item['suhu']?.toString() ?? '0') ?? 0;
    String status = item['status'] ?? '';

    if (status == 'Heat Stress') {
      return 'Suhu tubuh $namaSapi mencapai ${suhu.toStringAsFixed(1)}°C. Lingkungan terlalu panas, segera aktifkan pendingin kandang.';
    }
    return 'Suhu tubuh $namaSapi mencapai ${suhu.toStringAsFixed(1)}°C. Segera periksa kondisi fisik.';
  }

  Widget _buildNotificationCard(String title, String description, String timeBadge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFFEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCDD2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  timeBadge,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Abaikan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.phone, size: 16, color: Colors.white),
                  label: const Text('Hubungi Dokter', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
