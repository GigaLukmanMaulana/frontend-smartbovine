import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/navbar.dart';
import '../services/perangkat_service.dart';
import '../widgets/kelolaiot_skeleton.dart';
import '../services/sapi_service.dart';
import 'scan_feses_screen.dart';
import 'dashboard.dart';

class KelolaIotScreen extends StatefulWidget {
  const KelolaIotScreen({super.key});

  @override
  State<KelolaIotScreen> createState() => _KelolaIotScreenState();
}

class _KelolaIotScreenState extends State<KelolaIotScreen> {
  final int _selectedIndex = 2; // Index untuk 'Perangkat'
  List<dynamic> _sapiList = [];
  bool _isLoadingSapi = true;
  List<String> _assignedSapiIds = [];
  
  // Mengambil referensi ke seluruh root Firebase buat mendeteksi alat apa saja yg ada
  final DatabaseReference _dbRootRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _fetchSapiData();
  }

  Future<void> _fetchSapiData() async {
    final list = await SapiService.getSapi();
    if (mounted) {
      setState(() {
        _sapiList = list;
        _isLoadingSapi = false;
      });
    }
  }

  void _showAddDeviceDialog() {
    final TextEditingController collarIdCtrl = TextEditingController();
    final TextEditingController pathCtrl = TextEditingController();
    String? selectedSapiId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'Tambah Perangkat',
            style: TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final availableSapi = _sapiList.where((s) => !_assignedSapiIds.contains(s['id_sapi'].toString())).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(collarIdCtrl, 'Collar ID / Nama Alat (misal: Collar #103)'),
                    const SizedBox(height: 12),
                    
                    // Dropdown Sapi
                    if (_isLoadingSapi)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF00796B))),
                      )
                    else if (availableSapi.isEmpty && _sapiList.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Semua sapi sudah dipasangkan dengan perangkat, atau data sapi kosong.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedSapiId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: "",
                            child: Text('Kosongkan (Tanpa Sapi)'),
                          ),
                          ...availableSapi.map((sapi) {
                            return DropdownMenuItem<String>(
                              value: sapi['id_sapi'].toString(),
                              child: Text(sapi['nama_sapi'] ?? 'Sapi ID: ${sapi['id_sapi']}'),
                            );
                          }).toList()
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedSapiId = val);
                        },
                        decoration: InputDecoration(
                          labelText: 'Pilih Sapi',
                          filled: true,
                          fillColor: const Color(0xFFF1F4ED),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),
                    _buildTextField(pathCtrl, 'ID Perangkat MySQL & Path Firebase (misal: sapi_2)'),
                    const SizedBox(height: 8),
                    const Text(
                      'Pastikan ID Perangkat sesuai dengan program di ESP32 anda (contoh: sapi_1, sapi_2, dst).',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                );
              }
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (collarIdCtrl.text.isNotEmpty && pathCtrl.text.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context); // Tutup dialog

                  // 1. Simpan ke MySQL
                  final mysqlData = <String, dynamic>{
                    'id_perangkat': pathCtrl.text,
                    'status_alat': 'Aktif',
                    'rekam_data': 'Non Aktif' // Default non-aktif, bisa di toggle
                  };
                  if (selectedSapiId != null && selectedSapiId != "") {
                    mysqlData['id_sapi'] = selectedSapiId;
                  }
                  
                  final result = await PerangkatService.addPerangkat(mysqlData);

                  if (result['success'] == true) {
                    // Cari nama sapi
                    String namaSapi = 'Tanpa Sapi';
                    if (selectedSapiId != null && selectedSapiId != "") {
                      final selectedSapi = _sapiList.firstWhere((s) => s['id_sapi'].toString() == selectedSapiId, orElse: () => {});
                      namaSapi = selectedSapi['nama_sapi'] ?? 'Sapi Baru';
                    }

                    // 2. Simpan ke Firebase
                    FirebaseDatabase.instance.ref(pathCtrl.text).update({
                      'collar_id': collarIdCtrl.text,
                      'nama_sapi': namaSapi,
                      'id_sapi': selectedSapiId == "" ? null : selectedSapiId, // Simpan jg id_sapi di firebase
                      'is_active': true,
                      'is_recording': false,
                    });

                    messenger.showSnackBar(
                      const SnackBar(content: Text('Perangkat berhasil didaftarkan'), backgroundColor: Colors.green),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text(result['message'] ?? 'Gagal daftar perangkat'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // DIALOG UNTUK MENGEDIT PERANGKAT YANG SUDAH ADA
  void _showEditPerangkatDialog(Map<String, dynamic> dev) {
    final pathCtrl = TextEditingController(text: dev['path_key']);
    final collarIdCtrl = TextEditingController(text: dev['collar_id']);
    String? selectedSapiId = dev['id_sapi']?.toString();
    
    // Pastikan selectedSapiId ada di daftar, kalau tidak diset null
    if (selectedSapiId != null && !_sapiList.any((s) => s['id_sapi'].toString() == selectedSapiId)) {
      selectedSapiId = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            // Sapi yang tersedia adalah yang belum dipakai ATAU yang sedang dipakai oleh alat ini sendiri
            final availableSapi = _sapiList.where((s) {
              final id = s['id_sapi'].toString();
              return !_assignedSapiIds.contains(id) || id == dev['id_sapi']?.toString();
            }).toList();

            return AlertDialog(
              title: const Text('Edit Perangkat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (availableSapi.isEmpty && _sapiList.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Semua sapi sudah dipasangkan dengan perangkat, atau data sapi kosong.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedSapiId == null ? "" : (availableSapi.any((s) => s['id_sapi'].toString() == selectedSapiId) ? selectedSapiId : ""),
                        items: [
                          const DropdownMenuItem<String>(
                            value: "",
                            child: Text('Kosongkan (Tanpa Sapi)'),
                          ),
                          ...availableSapi.map((sapi) {
                            return DropdownMenuItem<String>(
                              value: sapi['id_sapi'].toString(),
                              child: Text(sapi['nama_sapi'] ?? 'Sapi ID: ${sapi['id_sapi']}'),
                            );
                          }).toList()
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedSapiId = val);
                        },
                        decoration: InputDecoration(
                          labelText: 'Pilih Sapi',
                          filled: true,
                          fillColor: const Color(0xFFF1F4ED),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),
                    _buildTextField(pathCtrl, 'ID Perangkat MySQL (misal: sapi_2)'),
                    const SizedBox(height: 8),
                    _buildTextField(collarIdCtrl, 'Collar ID (misal: C-2024)'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (collarIdCtrl.text.isNotEmpty && pathCtrl.text.isNotEmpty) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context); // Tutup dialog

                      // 1. Update ke MySQL
                      final mysqlData = <String, dynamic>{};
                      if (selectedSapiId != null && selectedSapiId != "") {
                        mysqlData['id_sapi'] = selectedSapiId;
                      } else {
                        mysqlData['id_sapi'] = null;
                      }
                      
                      final result = await PerangkatService.updatePerangkat(pathCtrl.text, mysqlData);

                      if (result['success'] == true) {
                        // Cari nama sapi
                        String namaSapi = 'Tanpa Sapi';
                        if (selectedSapiId != null && selectedSapiId != "") {
                          final selectedSapi = _sapiList.firstWhere((s) => s['id_sapi'].toString() == selectedSapiId, orElse: () => {});
                          namaSapi = selectedSapi['nama_sapi'] ?? 'Sapi Baru';
                        }

                        // 2. Update ke Firebase
                        FirebaseDatabase.instance.ref(pathCtrl.text).update({
                          'collar_id': collarIdCtrl.text,
                          'nama_sapi': namaSapi,
                          'id_sapi': selectedSapiId == "" ? null : selectedSapiId, // Simpan jg id_sapi di firebase
                        });

                        messenger.showSnackBar(
                          const SnackBar(content: Text('Perangkat berhasil diperbarui'), backgroundColor: Colors.green),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(content: Text(result['message'] ?? 'Gagal memperbarui perangkat'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF1F4ED),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _deleteDevice(String pathKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Perangkat'),
          content: Text('Yakin ingin menghapus perangkat $pathKey dari sistem? Semua riwayatnya bisa hilang.'),
          actions: [
             TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Tutup dialog
                
                // Hapus dari MySQL
                await PerangkatService.deletePerangkat(pathKey);
                
                // Menghapus node perangkat keseluruhan dari Firebase
                FirebaseDatabase.instance.ref(pathKey).remove();
                
                messenger.showSnackBar(
                  const SnackBar(content: Text('Perangkat dihapus'), backgroundColor: Colors.red),
                );
              },
              child: const Text('Hapus'),
            )
          ]
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00796B)),
          onPressed: () {
            // Pakai pushReplacement karena navbar memakai pushAndRemoveUntil
            // yang menghapus semua route, jadi pop() akan blank hitam
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Dashboard()),
            );
          },
        ),
        title: const Text(
          'Kelola Perangkat IoT',
          style: TextStyle(
            color: Color(0xFF00796B),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFB9DFD2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF00796B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Info Perangkat',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00796B),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pastikan perangkat Smart Collar aktif dan berada dalam jangkauan saat melakukan sinkronisasi.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                StreamBuilder(
                  stream: _dbRootRef.onValue,
                  builder: (context, AsyncSnapshot<DatabaseEvent> listSnapshot) {
                    // Tampilkan skeleton saat menunggu data pertama dari Firebase
                    if (listSnapshot.connectionState == ConnectionState.waiting) {
                      return const KelolaIotSkeleton();
                    }

                    List<Map<String, dynamic>> devices = [];

                    if (listSnapshot.hasData && listSnapshot.data?.snapshot.value != null) {
                      final dataValue = listSnapshot.data!.snapshot.value;
                      if (dataValue is Map) {
                        dataValue.forEach((key, value) {
                          String keyStr = key.toString();
                          // Anggap semua node yang berawalan "sapi" adalah alat yg teregistrasi
                          if (keyStr.startsWith('sapi')) {
                            final dev = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
                            dev['path_key'] = keyStr;
                            devices.add(dev);
                          }
                        });
                      }
                    }

                    _assignedSapiIds.clear();
                    for(var dev in devices) {
                      if (dev['id_sapi'] != null) {
                        _assignedSapiIds.add(dev['id_sapi'].toString());
                      }
                    }

                    int total = devices.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Daftar Perangkat',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: total > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$total Terhubung',
                                style: TextStyle(
                                  color: total > 0 ? const Color(0xFF00796B) : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (devices.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.devices_other, size: 40, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('Belum ada perangkat terhubung.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final dev = devices[index];
                              
                              // Data parsing
                              String pathKey = dev['path_key'];
                              String id = dev['collar_id'] ?? 'Collar #$pathKey';
                              String sapi = dev['nama_sapi'] ?? 'Sapi Baru';
                              double lat = (dev['lat'] ?? 0.0).toDouble();
                              String signal = lat != 0 ? 'Strong' : 'Weak'; 
                              String battery = dev.containsKey('bat') ? '${dev['bat']}%' : '85%';
                              bool isActive = dev['is_active'] == true; // Status alat (online/offline)
                              bool isRecording = dev['is_recording'] == true; // Status rekam data
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildDeviceCardUI(
                                  id: id,
                                  sapi: sapi,
                                  pathKey: pathKey,
                                  isActive: isActive,
                                  isRecording: isRecording,
                                  signal: signal,
                                  battery: battery,
                                  onDelete: () => _deleteDevice(pathKey),
                                  onEdit: () => _showEditPerangkatDialog(dev),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
                
                // Extra space for bottom button
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Tambah Perangkat Fixed Button
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _showAddDeviceDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Tambah Perangkat',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ),
        ],
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
          // Navbar sudah handle navigasi sendiri via pushAndRemoveUntil
        },
      ),
    );
  }

  Widget _buildDeviceCardUI({
    required String id,
    required String sapi,
    required String pathKey,
    required bool isActive,
    required bool isRecording,
    required String battery,
    required String signal,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sapi,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.battery_full, size: 16, color: isActive ? const Color(0xFF00796B) : Colors.grey),
              const SizedBox(width: 4),
              Text(battery, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              // Icon(Icons.signal_cellular_alt, size: 16, color: isActive ? const Color(0xFF00796B) : Colors.grey),
              // const SizedBox(width: 4),
              // Text(signal, style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle Status Alat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isActive ? Colors.green : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Alat (Online/Offline)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isActive ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isActive ? 'Tampil di Dashboard' : 'Disembunyikan',
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? Colors.green.shade600 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isActive,
                  activeColor: Colors.green,
                  onChanged: (val) async {
                    // Update Firebase
                    FirebaseDatabase.instance.ref(pathKey).update({'is_active': val});
                    // Update MySQL
                    await PerangkatService.updatePerangkat(pathKey, {
                      'status_alat': val ? 'Aktif' : 'Non Aktif'
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Toggle Data Latih
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isRecording ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isRecording ? Colors.green : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Rekam (Data Latih)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isRecording ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRecording ? 'Merekam ke MySQL (Tiap 5 Detik)...' : 'Mati (Tidak Merekam)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isRecording ? Colors.green.shade600 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isRecording,
                  activeColor: Colors.green,
                  onChanged: (val) async {
                    // Update Firebase
                    FirebaseDatabase.instance.ref(pathKey).update({'is_recording': val});
                    // Update MySQL
                    await PerangkatService.updatePerangkat(pathKey, {
                      'rekam_data': val ? 'Aktif' : 'Non Aktif'
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tombol Edit dan Hapus
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00796B),
                    side: const BorderSide(color: Color(0xFF00796B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFFEBEE)),
                    backgroundColor: const Color(0xFFFFEBEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Hapus'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
