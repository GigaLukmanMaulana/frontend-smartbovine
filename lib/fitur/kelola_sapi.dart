import 'package:flutter/material.dart';
import '../services/sapi_service.dart';

enum SortKategori { waktu, berat, umur, nama }

class KelolaSapiScreen extends StatefulWidget {
  const KelolaSapiScreen({super.key});

  @override
  State<KelolaSapiScreen> createState() => _KelolaSapiScreenState();
}

class _KelolaSapiScreenState extends State<KelolaSapiScreen> {
  // Data dari API
  List<dynamic> _daftarSapi = [];
  bool _isLoading = false;

  SortKategori _activeSort = SortKategori.waktu;
  bool _isAscending = false; // default false = terbaru, terberat, tertua

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _umurController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();

  String? _selectedJenisKelamin;
  String? _selectedJenisSapi;

  final List<String> _jenisKelaminOptions = ['Jantan', 'Betina'];
  final List<String> _jenisSapiOptions = [
    'Limosin', 'Simmental', 'Brahman', 'Bali', 'Madura', 
    'PO', 'Angus', 'Hereford', 'Brahman Cross', 'Aceh'
  ];

  @override
  void initState() {
    super.initState();
    _fetchSapi();
  }

  Future<void> _fetchSapi() async {
    setState(() => _isLoading = true);
    final data = await SapiService.getSapi();
    if (mounted) {
      setState(() {
        _daftarSapi = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _umurController.dispose();
    _beratController.dispose();
    super.dispose();
  }

  void _showTambahSapiDialog() {
    // Reset field
    _namaController.clear();
    _umurController.clear();
    _beratController.clear();
    _selectedJenisKelamin = null;
    _selectedJenisSapi = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pets, color: Color(0xFF2E7D32), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tambah Sapi Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(
                controller: _namaController,
                label: 'Nama / ID Sapi (Opsional)',
                icon: Icons.badge_outlined,
                hint: 'Contoh: Sapi #2',
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                value: _selectedJenisSapi,
                items: _jenisSapiOptions,
                label: 'Jenis / Ras',
                icon: Icons.category_outlined,
                onChanged: (val) {
                  setDialogState(() => _selectedJenisSapi = val);
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                value: _selectedJenisKelamin,
                items: _jenisKelaminOptions,
                label: 'Jenis Kelamin',
                icon: Icons.wc_outlined,
                onChanged: (val) {
                  setDialogState(() => _selectedJenisKelamin = val);
                },
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: _umurController,
                label: 'Umur (Bulan)',
                icon: Icons.calendar_today_outlined,
                hint: 'Contoh: 12',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: _beratController,
                label: 'Berat (Kg) - Opsional',
                icon: Icons.scale_outlined,
                hint: 'Contoh: 450.5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (_selectedJenisKelamin == null || _selectedJenisSapi == null || _umurController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Jenis Kelamin, Jenis/Ras, dan Umur wajib diisi!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context); // Tutup dialog dulu
              setState(() => _isLoading = true);

              final sapiData = {
                'nama_sapi': _namaController.text.isEmpty ? null : _namaController.text,
                'jenis_sapi': _selectedJenisSapi,
                'jenis_kelamin': _selectedJenisKelamin,
                'umur_bulan': int.tryParse(_umurController.text) ?? 0,
                'berat_kg': _beratController.text.isEmpty ? null : double.tryParse(_beratController.text),
              };

              final result = await SapiService.addSapi(sapiData);
              
              if (!mounted) return;

              if (result['success'] == true) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Sapi berhasil ditambahkan!'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
                _fetchSapi(); // Refresh data
              } else {
                setState(() => _isLoading = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Gagal menambahkan sapi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F4ED),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F4ED),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kelola Sapi',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showTambahSapiDialog,
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
            tooltip: 'Tambah Sapi',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))) 
          : _daftarSapi.isEmpty ? _buildEmptyState() : _buildDaftarSapi(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTambahSapiDialog,
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Sapi', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets,
              size: 64,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum Ada Data Sapi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tambahkan sapi baru untuk mulai\nmemantau kesehatan ternak Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showTambahSapiDialog,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Sapi Pertama'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaftarSapi() {
    final List<dynamic> sortedList = List.from(_daftarSapi);
    sortedList.sort((a, b) {
      int result = 0;
      switch (_activeSort) {
        case SortKategori.waktu:
          int idA = a['id_sapi'] ?? 0;
          int idB = b['id_sapi'] ?? 0;
          result = idA.compareTo(idB);
          break;
        case SortKategori.berat:
          double beratA = (a['berat_kg'] != null) ? double.tryParse(a['berat_kg'].toString()) ?? 0.0 : 0.0;
          double beratB = (b['berat_kg'] != null) ? double.tryParse(b['berat_kg'].toString()) ?? 0.0 : 0.0;
          result = beratA.compareTo(beratB);
          break;
        case SortKategori.umur:
          int umurA = a['umur_bulan'] ?? 0;
          int umurB = b['umur_bulan'] ?? 0;
          result = umurA.compareTo(umurB);
          break;
        case SortKategori.nama:
          String namaA = (a['nama_sapi'] ?? 'Z').toLowerCase();
          String namaB = (b['nama_sapi'] ?? 'Z').toLowerCase();
          result = namaA.compareTo(namaB);
          break;
      }
      return _isAscending ? result : -result;
    });

    return Column(
      children: [
        _buildSortChips(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sortedList.length,
            itemBuilder: (context, index) {
              final sapi = sortedList[index];
        final idSapi = sapi['id_sapi'];
        final namaSapi = sapi['nama_sapi'] ?? 'Sapi Tanpa Nama';
        final jenisKelamin = sapi['jenis_kelamin'] ?? '-';
        final jenisSapi = sapi['jenis_sapi'] ?? '-';
        final umurBulan = sapi['umur_bulan'] ?? 0;
        final beratKg = sapi['berat_kg'] ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
              child: const Icon(Icons.pets, color: Color(0xFF2E7D32)),
            ),
            title: Text(
              namaSapi,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$jenisKelamin • $jenisSapi • Umur: $umurBulan bln • Berat: $beratKg kg',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'hapus') {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  final success = await SapiService.deleteSapi(idSapi);
                  if (!mounted) return;
                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('$namaSapi dihapus'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _fetchSapi();
                  } else {
                    setState(() => _isLoading = false);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Gagal menghapus sapi'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'hapus',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
    ),
    ],
    );
  }

  Widget _buildSortChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _sortChip('Waktu', SortKategori.waktu),
          const SizedBox(width: 8),
          _sortChip('Berat', SortKategori.berat),
          const SizedBox(width: 8),
          _sortChip('Umur', SortKategori.umur),
          const SizedBox(width: 8),
          _sortChip('Nama', SortKategori.nama),
        ],
      ),
    );
  }

  Widget _sortChip(String label, SortKategori kategori) {
    final isActive = _activeSort == kategori;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isActive) ...[
            const SizedBox(width: 4),
            Icon(
              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            ),
          ]
        ],
      ),
      selected: isActive,
      selectedColor: const Color(0xFF2E7D32).withOpacity(0.2),
      onSelected: (_) {
        setState(() {
          if (_activeSort == kategori) {
            _isAscending = !_isAscending;
          } else {
            _activeSort = kategori;
            _isAscending = (kategori == SortKategori.nama); // A-Z default utk nama
          }
        });
      },
    );
  }
}
