import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/dashboard_skeleton.dart';
import '../widgets/navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_feses_screen.dart';
import 'notifikasi.dart';
import 'kelolaiot.dart';
import 'kelola_sapi.dart';
import 'device_monitor.dart'; // Impor screen baru
import '../services/perangkat_service.dart';
import 'mitra_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _namaUser = "User";
  String _inisialUser = "U";

  List<dynamic> _perangkatList = [];
  bool _isLoading = true;

  // Notifikasi badge — listen real-time dari Firebase
  int _notifCount = 0;
  late final StreamSubscription<DatabaseEvent> _notifSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPerangkatData();
    _listenNotifications();
  }

  @override
  void dispose() {
    _notifSubscription.cancel();
    super.dispose();
  }

  /// Listen jumlah notifikasi BELUM DIBACA dari Firebase path 'notifikasi'
  void _listenNotifications() {
    final notifRef = FirebaseDatabase.instance.ref('notifikasi');
    _notifSubscription = notifRef.onValue.listen((event) {
      int count = 0;
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        // Hanya hitung notifikasi yang belum dibaca
        data.forEach((key, value) {
          if (value is Map && value['dibaca'] != true) {
            count++;
          }
        });
      }
      if (mounted) {
        setState(() => _notifCount = count);
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _namaUser = prefs.getString("nama") ?? "Peternak";
      _inisialUser = _namaUser.isNotEmpty ? _namaUser[0].toUpperCase() : "P";
    });
  }

  Future<void> _fetchPerangkatData() async {
    setState(() => _isLoading = true);

    // TODO: Hapus delay ini setelah selesai testing skeleton loader
    await Future.delayed(const Duration(seconds: 1));

    final data = await PerangkatService.getPerangkat();
    if (mounted) {
      setState(() {
        // Hanya tampilkan perangkat yang status_alat-nya 'Aktif'
        _perangkatList = data.where((device) => device['status_alat'] == 'Aktif').toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FBF9),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF00796B)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _inisialUser,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00796B),
                  ),
                ),
              ),
              accountName: Text(
                _namaUser,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: const Text("Administrator SmartBovine"),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Beranda'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
              title: const Text('Tambah Sapi'),
              onTap: () {
                Navigator.pop(context); // tutup drawer dulu
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KelolaSapiScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined, color: Color(0xFF00796B)),
              title: const Text('Mitra'),
              onTap: () {
                Navigator.pop(context); // tutup drawer dulu
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MitraScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
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
                  builder: (context) => const NotifikasiScreen(
                    currentStatus: "Memuat...",
                    currentSuhu: 0.0,
                  ),
                ),
              );
            },
            icon: _notifCount > 0
              ? Badge(
                  label: Text('$_notifCount'),
                  child: const Icon(Icons.notifications_none, color: Colors.black87),
                )
              : const Icon(Icons.notifications_none, color: Colors.black87),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF00796B),
                child: Text(
                  _inisialUser,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPerangkatData,
        color: const Color(0xFF00796B),
        child: _isLoading 
          ? const DashboardSkeleton()
          : _perangkatList.isEmpty 
            ? _buildEmptyState()
            : _buildDeviceList(),
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
                _fetchPerangkatData(); // Refresh data ketika kembali dari Kelola IoT
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

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.devices_other,
                  size: 64,
                  color: Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Belum Ada Perangkat Aktif',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pasangkan collar ke sapi dan daftarkan\nperangkat di menu Kelola IoT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KelolaIotScreen()),
                  ).then((_) => _fetchPerangkatData());
                },
                icon: const Icon(Icons.add),
                label: const Text('Daftarkan Perangkat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _perangkatList.length + 1, // +1 untuk header
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Pilih Sapi untuk Dimonitor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          );
        }

        final perangkat = _perangkatList[index - 1];
        final sapi = perangkat['sapi'] ?? {};
        final idPerangkat = perangkat['id_perangkat'] ?? 'Unknown';
        final namaSapi = sapi['nama_sapi'] ?? 'Sapi Tanpa Nama';
        final jenisKelamin = sapi['jenis_kelamin'] ?? '-';
        final isAktif = perangkat['status_alat'] == 'Aktif';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceMonitorScreen(perangkatData: perangkat),
                ),
              );
            },
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF00796B).withOpacity(0.1),
                    child: const Icon(Icons.pets, color: Color(0xFF00796B), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaSapi,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$jenisKelamin • Perangkat: $idPerangkat',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAktif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isAktif ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  color: isAktif ? Colors.green : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
