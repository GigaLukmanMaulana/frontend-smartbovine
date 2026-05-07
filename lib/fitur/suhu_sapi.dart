import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'scan_feses_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/navbar.dart';
import '../widgets/riwayat_skeleton.dart';
import '../services/auth_service.dart';
import '../services/perangkat_service.dart';
import 'dashboard.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

String _selectedPeriod = 'default'; // Default periode

class _ReportScreenState extends State<ReportScreen> {
  // Warna tema (Green Teal)
  final Color primaryColor = const Color(0xFF00695C);
  final Color backgroundColor = const Color(0xFFF1F8F1);
  final Color cardColor = Colors.white;
  final Color activityCardColor = const Color(0xFFE0F7FA);

  // State Management
  List<dynamic> _historyData = [];
  List<dynamic> _activityData = [];
  List<dynamic> _filteredActivityData = []; // Filtered data for display
  bool _isLoading = true;
  bool _isActivityLoading = false; // Separate loading state for activity
  int _selectedView = 0; // 0: Suhu, 1: Aktivitas
  String selectedSapi = 'Sapi #1024 (Bessie)';
  String _selectedActivityPeriod = 'default'; // Default periode untuk aktivitas

  // Performance optimization - caching
  Map<String, List<dynamic>> _activityCache = {};
  Map<String, int> _todayActivityCache = {};
  Map<String, double> _averageActivityCache = {};
  DateTime? _lastActivityFetch;

  List<dynamic> _perangkatList = [];
  String? _selectedPerangkatId;

  // Zoom state untuk grafik suhu
  double _suhuMinX = 0;
  double _suhuMaxX = 20;
  double _suhuBaseRange = 20;
  double _suhuLastScale = 1.0;

  // Zoom state untuk grafik aktivitas
  double _actMinX = 0;
  double _actMaxX = 20;
  double _actBaseRange = 20;
  double _actLastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchPerangkatList();
  }

  @override
  void dispose() {
    _activityCache.clear();
    _todayActivityCache.clear();
    _averageActivityCache.clear();
    super.dispose();
  }

  // --- LOGIKA DATA DINAMIS ---
  Future<void> _fetchPerangkatList() async {
    final data = await PerangkatService.getPerangkat();
    if (mounted) {
      setState(() {
        _perangkatList = data;
        if (_perangkatList.isNotEmpty) {
          _selectedPerangkatId = _perangkatList.first['id_perangkat'];
        }
      });
      if (_selectedPerangkatId != null) {
        _fetchHistory();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      // Kirim parameter period dan id_perangkat ke Laravel
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/sapi-history?period=$_selectedPeriod&id_perangkat=${_selectedPerangkatId ?? ''}',
            ),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _historyData = json.decode(response.body);
          _isLoading = false;
          // Reset zoom sesuai jumlah data
          _suhuMinX = 0;
          _suhuMaxX = _historyData.length.toDouble().clamp(5, double.infinity);
          _suhuBaseRange = _suhuMaxX;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActivityData() async {
    // Check cache first
    final cacheKey = _selectedActivityPeriod;
    final now = DateTime.now();

    // Use cache if available and not older than 5 minutes
    if (_activityCache.containsKey(cacheKey) &&
        _lastActivityFetch != null &&
        now.difference(_lastActivityFetch!).inMinutes < 5) {
      setState(() {
        _activityData = _activityCache[cacheKey]!;
        _filteredActivityData = _filterActivitiesForDisplay(
          _activityCache[cacheKey]!,
        );
        _isActivityLoading = false;
      });
      return;
    }

    setState(() => _isActivityLoading = true);
    try {
      // Kirim parameter period dan id_perangkat ke Laravel untuk aktivitas
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/aktivitas-sapi?period=$_selectedActivityPeriod&id_perangkat=${_selectedPerangkatId ?? ''}',
            ),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 15)); // Increased timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Filter hanya aktivitas berjalan (exclude makan dan minum)
        final filteredData = data.where((item) {
          final aktivitas = (item['aktivitas'] ?? '').toString().toLowerCase();
          return aktivitas.contains('berjalan') ||
              aktivitas.contains('jalan') ||
              !aktivitas.contains('makan') && !aktivitas.contains('minum');
        }).toList();

        setState(() {
          _activityData = filteredData;
          // Apply additional filtering for display
          _filteredActivityData = _filterActivitiesForDisplay(filteredData);
          _isActivityLoading = false;
          // Reset zoom aktivitas
          _actMinX = 0;
          _actMaxX = filteredData.length.toDouble().clamp(5, double.infinity);
          _actBaseRange = _actMaxX;
          // Update cache with filtered data
          _activityCache[cacheKey] = filteredData;
          _lastActivityFetch = now;
          // Clear related caches
          _todayActivityCache.remove(cacheKey);
          _averageActivityCache.remove(cacheKey);
        });
      } else {
        setState(() => _isActivityLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching activity data: $e");
      setState(() => _isActivityLoading = false);
    }
  }

  String _calculateStats(String type, [String field = 'suhu']) {
    if (_historyData.isEmpty) return "0.0";
    List<double> values = _historyData
        .map((e) => double.parse(e[field].toString()))
        .toList();

    if (type == 'max')
      return values.reduce((a, b) => a > b ? a : b).toStringAsFixed(1);
    if (type == 'min')
      return values.reduce((a, b) => a < b ? a : b).toStringAsFixed(1);
    if (type == 'avg')
      return (values.reduce((a, b) => a + b) / values.length).toStringAsFixed(
        1,
      );
    return "0.0";
  }

  List<FlSpot> _getSuhuSpots() {
    return _historyData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        double.parse(entry.value['suhu'].toString()),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Dashboard()),
            );
          },
        ),
        title: Text(
          'Riwayat & Laporan',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
        ? const RiwayatSkeleton()
        : RefreshIndicator(
        onRefresh: _refreshCurrentView,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // --- Header: Dropdown Sapi & Kalender ---
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPerangkatId,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00695C)),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          elevation: 4,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedPerangkatId = newValue);
                              _refreshCurrentView(); // Reload data sesuai perangkat baru
                            }
                          },
                          items: _perangkatList.map<DropdownMenuItem<String>>((perangkat) {
                            final sapi = perangkat['sapi'] ?? {};
                            final namaSapi = sapi['nama_sapi'] ?? 'Sapi';
                            final label = '$namaSapi (${perangkat['id_perangkat']})';
                            return DropdownMenuItem<String>(
                              value: perangkat['id_perangkat'].toString(),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pets,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(label),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildViewSelector(),
              const SizedBox(height: 15),

              // Show loading only for specific sections
              if (_selectedView == 1 && _isActivityLoading) ...[
                const SizedBox(height: 50),
                Center(child: CircularProgressIndicator(color: primaryColor)),
                const SizedBox(height: 50),
              ] else if (_selectedView != 1) ...[
                _buildRangeInfo(),
                const SizedBox(height: 20),
                _buildChartCard(),
                const SizedBox(height: 30),
                _buildTemperatureDownloadSection(),
                const SizedBox(height: 30),
              ] else ...[
                _buildActivityRangeInfo(),
                const SizedBox(height: 20),
                _buildActivityTrendCard(),
                const SizedBox(height: 30),
                _buildActivityChartCard(),
                const SizedBox(height: 30),
                _buildSimpleActivityList(),
                const SizedBox(height: 30),
                _buildActivityDownloadSection(),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
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
        selectedIndex: 3,
        onItemSelected: (index) {
          // Fungsi ini wajib ada untuk memenuhi parameter constructor
          debugPrint("Pindah ke index: $index");
        },
      ),
    );
  }

  // --- WIDGET COMPONENTS ---



  Widget _buildRangeInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Filter Periode:',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Row(
          children: [
            _buildPeriodChip('Default', 'default'),
            const SizedBox(width: 5),
            _buildPeriodChip('1 Jam', '1hour'),
            const SizedBox(width: 5),
            _buildPeriodChip('1 Hari', '1day'),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    bool isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = value;
        });
        _fetchHistory(); // Ambil data ulang saat filter diganti
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final String title = 'Tren Suhu';
    final String subtitle = 'Suhu Tubuh';
    final String field = 'suhu';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(children: [_buildLegendDot(Colors.green, 'Tubuh')]),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatInfo(
                'Maksimum',
                '${_calculateStats('max', field)}°C',
                Colors.red,
              ),
              _buildStatInfo(
                'Rata-rata',
                '${_calculateStats('avg', field)}°C',
                Colors.black,
              ),
              _buildStatInfo(
                'Minimum',
                '${_calculateStats('min', field)}°C',
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Zoom indicator + reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pinch, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Cubit untuk zoom periode • Geser untuk navigasi',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
              if (_suhuMaxX - _suhuMinX < _suhuBaseRange - 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _suhuMinX = 0;
                    _suhuMaxX = _suhuBaseRange;
                  }),
                  child: Row(
                    children: [
                      Icon(Icons.zoom_out_map, size: 14, color: primaryColor),
                      const SizedBox(width: 2),
                      Text('Reset', style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onScaleStart: (_) => _suhuLastScale = 1.0,
            onScaleUpdate: (details) {
              if (_historyData.isEmpty) return;
              final maxLen = _historyData.length.toDouble();
              final range = _suhuMaxX - _suhuMinX;
              final center = (_suhuMinX + _suhuMaxX) / 2;

              if (details.scale != 1.0) {
                // Pinch zoom
                final scaleDiff = details.scale - _suhuLastScale;
                var newRange = range * (1 - scaleDiff * 0.5);
                newRange = newRange.clamp(5.0, maxLen);
                setState(() {
                  _suhuMinX = (center - newRange / 2).clamp(0, maxLen - 5);
                  _suhuMaxX = (_suhuMinX + newRange).clamp(5, maxLen);
                  _suhuLastScale = details.scale;
                });
              } else {
                // Pan (geser)
                final dx = -details.focalPointDelta.dx * range / 300;
                setState(() {
                  var newMin = (_suhuMinX + dx).clamp(0.0, maxLen - range);
                  _suhuMinX = newMin;
                  _suhuMaxX = newMin + range;
                });
              }
            },
            child: SizedBox(
              height: 200, 
              child: ClipRect(
                child: LineChart(sampleData())
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildViewChip('Suhu Tubuh', 0),
        _buildViewChip('Aktivitas', 1),
      ],
    );
  }

  Widget _buildViewChip(String label, int value) {
    bool isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedView = value;
        });
        if (value == 1) {
          _fetchActivityData();
        } else {
          _fetchHistory();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _refreshCurrentView() async {
    if (_selectedView == 1) {
      await _fetchActivityData();
    } else {
      await _fetchHistory();
    }
  }

  Widget _buildActivityRangeInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Filter Periode:',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Row(
          children: [
            _buildActivityPeriodChip('Default', 'default'),
            const SizedBox(width: 5),
            _buildActivityPeriodChip('1 Jam', '1hour'),
            const SizedBox(width: 5),
            _buildActivityPeriodChip('1 Hari', '1day'),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityPeriodChip(String label, String value) {
    bool isSelected = _selectedActivityPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivityPeriod = value;
        });
        _fetchActivityData(); // Ambil data ulang saat filter diganti
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTrendCard() {
    // Calculate most frequent activity
    String mostFrequentActivity = _getMostFrequentActivity();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Aktivitas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  _buildLegendDot(const Color(0xFF3949AB), 'Aktivitas'),
                ],
              ),
            ],
          ),
          const Text(
            'Analisis Pergerakan Sapi',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // _buildStatInfo(
              //   'Aktivitas Terbanyak',
              //   mostFrequentActivity,
              //   const Color(0xFF3949AB),
              // ),
              _buildStatInfo(
                'Durasi Aktif',
                _getActiveDuration(),
                Colors.green,
              ),
              _buildStatInfo('Durasi Diam', _getIdleDuration(), Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grafik Aktivitas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  _buildLegendDot(Colors.grey, 'Diam (0)'),
                  _buildLegendDot(Colors.green, 'Aktif (1)'),
                ],
              ),
            ],
          ),
          const Text(
            'Visualisasi Aktivitas Per Waktu',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pinch, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Cubit untuk zoom • Geser untuk navigasi',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
              if (_actMaxX - _actMinX < _actBaseRange - 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _actMinX = 0;
                    _actMaxX = _actBaseRange;
                  }),
                  child: Row(
                    children: [
                      Icon(Icons.zoom_out_map, size: 14, color: primaryColor),
                      const SizedBox(width: 2),
                      Text('Reset', style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onScaleStart: (_) => _actLastScale = 1.0,
            onScaleUpdate: (details) {
              if (_activityData.isEmpty) return;
              final maxLen = _activityData.length.toDouble();
              final range = _actMaxX - _actMinX;
              final center = (_actMinX + _actMaxX) / 2;

              if (details.scale != 1.0) {
                final scaleDiff = details.scale - _actLastScale;
                var newRange = range * (1 - scaleDiff * 0.5);
                newRange = newRange.clamp(5.0, maxLen);
                setState(() {
                  _actMinX = (center - newRange / 2).clamp(0, maxLen - 5);
                  _actMaxX = (_actMinX + newRange).clamp(5, maxLen);
                  _actLastScale = details.scale;
                });
              } else {
                final dx = -details.focalPointDelta.dx * range / 300;
                setState(() {
                  var newMin = (_actMinX + dx).clamp(0.0, maxLen - range);
                  _actMinX = newMin;
                  _actMaxX = newMin + range;
                });
              }
            },
            child: SizedBox(
              height: 200, 
              child: ClipRect(
                child: LineChart(activityChartData())
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleActivityList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Aktivitas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 15),
          _filteredActivityData.isEmpty
              ? const Text('Tidak ada data aktivitas saat ini.')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredActivityData.length > 5
                      ? 5
                      : _filteredActivityData.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _filteredActivityData[index];
                    final waktu = item['waktu'] ?? item['created_at'] ?? '';
                    final aktivitas = item['aktivitas'] ?? 'Tidak diketahui';
                    final statusSederhana = _getStatusSederhana(aktivitas);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatDateTime(waktu),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              statusSederhana,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          if (_filteredActivityData.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Menampilkan 5 dari ${_filteredActivityData.length} aktivitas',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityDownloadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unduh Laporan Aktivitas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadActivityReport(),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text(
                'Unduh PDF',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureDownloadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unduh Laporan Suhu Tubuh',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadTemperatureReport(),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text(
                'Unduh PDF',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PDF GENERATION HELPERS ---

  bool _isDownloading = false;

  Future<String> _getDownloadPath() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir.path;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Coba minta permission MANAGE_EXTERNAL_STORAGE dulu
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Fallback ke storage biasa
        await Permission.storage.request();
      }
    }
  }

  // === Generate PDF Laporan Suhu ===
  Future<Uint8List> _generateTemperaturePdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#00695C'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SmartBovine - Laporan Suhu Tubuh',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Sapi: $selectedSapi',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Dicetak: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Periode: $_selectedPeriod',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Ringkasan Statistik
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatItem('Maksimum', '${_calculateStats('max')}°C', PdfColors.red),
                  _pdfStatItem('Rata-rata', '${_calculateStats('avg')}°C', PdfColors.black),
                  _pdfStatItem('Minimum', '${_calculateStats('min')}°C', PdfColors.blue),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Label tabel
            pw.Text(
              'Data Riwayat Suhu (${_historyData.length} catatan)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            // Tabel Data
            if (_historyData.isNotEmpty)
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF00695C),
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.center,
                headerAlignment: pw.Alignment.center,
                headers: ['No', 'Waktu', 'Suhu Tubuh (°C)'],
                data: _historyData.asMap().entries.map((entry) {
                  final item = entry.value;
                  final waktu = item['created_at'] ?? item['waktu'] ?? '-';
                  final suhu = item['suhu']?.toString() ?? '-';
                  return [
                    '${entry.key + 1}',
                    _formatDateTimeFull(waktu.toString()),
                    suhu,
                  ];
                }).toList(),
              )
            else
              pw.Text('Tidak ada data tersedia.',
                  style: const pw.TextStyle(fontSize: 11)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // === Generate PDF Laporan Aktivitas ===
  Future<Uint8List> _generateActivityPdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#3949AB'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SmartBovine - Laporan Aktivitas Sapi',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Sapi: $selectedSapi',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Dicetak: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Periode: $_selectedActivityPeriod',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Ringkasan
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatItem('Total Data', '${_activityData.length}', PdfColors.indigo),
                  _pdfStatItem('Durasi Aktif', _getActiveDuration(), PdfColors.green),
                  _pdfStatItem('Durasi Diam', _getIdleDuration(), PdfColors.orange),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Label
            pw.Text(
              'Data Riwayat Aktivitas (${_activityData.length} catatan)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            // Tabel Data
            if (_activityData.isNotEmpty)
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF3949AB),
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.center,
                headerAlignment: pw.Alignment.center,
                headers: ['No', 'Waktu', 'Aktivitas', 'Status'],
                data: _activityData.asMap().entries.map((entry) {
                  final item = entry.value;
                  final waktu = item['waktu'] ?? item['created_at'] ?? '-';
                  final aktivitas = item['aktivitas'] ?? '-';
                  final status = _getStatusSederhana(aktivitas.toString());
                  return [
                    '${entry.key + 1}',
                    _formatDateTimeFull(waktu.toString()),
                    aktivitas.toString(),
                    status,
                  ];
                }).toList(),
              )
            else
              pw.Text('Tidak ada data tersedia.',
                  style: const pw.TextStyle(fontSize: 11)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helper untuk item statistik di PDF
  pw.Widget _pdfStatItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // Format datetime lengkap untuk PDF
  String _formatDateTimeFull(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  // === Save & Open PDF ===
  Future<void> _savePdfAndOpen(Uint8List pdfBytes, String filename) async {
    try {
      await _requestStoragePermission();
      final downloadPath = await _getDownloadPath();
      final filePath = '$downloadPath/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('$filename berhasil disimpan!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'BUKA',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Gagal menyimpan: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // === Download Handlers ===
  Future<void> _downloadTemperatureReport() async {
    if (_isDownloading || _historyData.isEmpty) {
      if (_historyData.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data suhu untuk diunduh.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isDownloading = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Membuat laporan suhu...'),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: primaryColor,
        ),
      );
    }

    try {
      final pdfBytes = await _generateTemperaturePdf();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'Laporan_Suhu_$timestamp.pdf';
      await _savePdfAndOpen(pdfBytes, filename);
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _downloadActivityReport() async {
    if (_isDownloading || _activityData.isEmpty) {
      if (_activityData.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data aktivitas untuk diunduh.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isDownloading = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Membuat laporan aktivitas...'),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: const Color(0xFF3949AB),
        ),
      );
    }

    try {
      final pdfBytes = await _generateActivityPdf();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'Laporan_Aktivitas_$timestamp.pdf';
      await _savePdfAndOpen(pdfBytes, filename);
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _downloadCurrentReport() async {
    if (_selectedView == 1) {
      await _downloadActivityReport();
    } else {
      await _downloadTemperatureReport();
    }
  }

  Widget _buildDownloadButton() {
    final label = _selectedView == 1
        ? 'Unduh Laporan Aktivitas'
        : 'Unduh Laporan Suhu Tubuh';
    final buttonColor = _selectedView == 1
        ? const Color(0xFF3949AB)
        : const Color(0xFF8D6E63);

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _downloadCurrentReport,
        icon: const Icon(Icons.file_download_outlined, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildLegendDot(Color color, String label, {bool isDashed = false}) {
    return Row(
      children: [
        isDashed
            ? Text(
                '---',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              )
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatInfo(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // --- KONFIGURASI GRAFIK DINAMIS ---

  LineChartData sampleData() {
    return LineChartData(
      clipData: const FlClipData.all(), // Mencegah grafik keluar batas saat dizoom
      minX: _suhuMinX,
      maxX: _suhuMaxX,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              String waktu = '';
              if (spot.x.toInt() < _historyData.length) {
                try {
                  DateTime date = DateTime.parse(_historyData[spot.x.toInt()]['created_at']);
                  waktu = DateFormat('HH:mm').format(date);
                } catch (_) {}
              }
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)}°C\n$waktu',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1, // evaluate every point
            getTitlesWidget: (value, meta) {
              if (_historyData.isEmpty ||
                  value.toInt() >= _historyData.length ||
                  value < 0)
                return const Text('');
                
              final range = _suhuMaxX - _suhuMinX;
              final displayInterval = (range / 5).ceil().clamp(1, 100);
              
              if (value.toInt() % displayInterval != 0) {
                 return const Text('');
              }

              DateTime date = DateTime.parse(
                _historyData[value.toInt()]['created_at'],
              );
              
              // Jika range data yang tampil besar, tampilkan tanggal, jika kecil tampilkan jam
              String format = range > 50 ? 'dd MMM' : 'HH:mm';

              return SideTitleWidget(
                meta: meta,
                space: 10,
                child: Text(
                  DateFormat(format).format(date),
                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}°',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _getSuhuSpots().isEmpty
              ? [const FlSpot(0, 37)]
              : _getSuhuSpots(),
          isCurved: true,
          color: Colors.green.shade700,
          barWidth: 4,
          isStrokeCapRound: true,
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.shade700.withOpacity(0.1),
          ),
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  // --- Helper Methods for Activity Data ---

  String _getMostFrequentActivity() {
    if (_activityData.isEmpty) return 'Tidak ada';

    Map<String, int> activityCounts = {};
    for (var item in _activityData) {
      final aktivitas = item['aktivitas'] ?? 'Tidak diketahui';
      activityCounts[aktivitas] = (activityCounts[aktivitas] ?? 0) + 1;
    }

    if (activityCounts.isEmpty) return 'Tidak ada';

    String mostFrequent = '';
    int maxCount = 0;

    activityCounts.forEach((aktivitas, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = aktivitas;
      }
    });

    return mostFrequent;
  }

  String _getActiveDuration() {
    if (_activityData.isEmpty) return '0 jam';

    int activeCount = 0;
    for (var item in _activityData) {
      final aktivitas = (item['aktivitas'] ?? '').toString().toLowerCase();
      if (aktivitas.contains('berjalan') ||
          aktivitas.contains('makan') ||
          aktivitas.contains('minum')) {
        activeCount++;
      }
    }

    // Estimate duration (assuming each activity takes ~30 minutes)
    final hours = (activeCount * 0.5).round();
    return '$hours jam';
  }

  String _getIdleDuration() {
    if (_activityData.isEmpty) return '0 jam';

    int idleCount = 0;
    for (var item in _activityData) {
      final aktivitas = (item['aktivitas'] ?? '').toString().toLowerCase();
      if (!aktivitas.contains('berjalan') &&
          !aktivitas.contains('makan') &&
          !aktivitas.contains('minum')) {
        idleCount++;
      }
    }

    // Estimate duration (assuming each idle period takes ~1 hour)
    final hours = idleCount;
    return '$hours jam';
  }

  String _getStatusSederhana(String aktivitas) {
    final aktivitasLower = aktivitas.toLowerCase();

    if (aktivitasLower.contains('berjalan') ||
        aktivitasLower.contains('jalan') ||
        aktivitasLower.contains('makan') ||
        aktivitasLower.contains('minum')) {
      return 'Aktif';
    } else {
      return 'Diam';
    }
  }

  List<dynamic> _filterActivitiesForDisplay(List<dynamic> activities) {
    // Return all activities without filtering
    return activities;
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  List<FlSpot> _getActivitySpots() {
    if (_activityData.isEmpty) return [const FlSpot(0, 0)];

    // Create activity level mapping: Diam=0, Bergerak=1, Aktif=2
    List<FlSpot> spots = [];

    for (int i = 0; i < _activityData.length; i++) {
      final item = _activityData[i];
      final aktivitas = (item['aktivitas'] ?? '').toString().toLowerCase();

      double activityLevel = 0; // Default: Diam
      if (aktivitas.contains('berjalan') ||
          aktivitas.contains('jalan') ||
          aktivitas.contains('makan') ||
          aktivitas.contains('minum')) {
        activityLevel = 1; // Aktif
      }

      spots.add(FlSpot(i.toDouble(), activityLevel));
    }

    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  LineChartData activityChartData() {
    return LineChartData(
      clipData: const FlClipData.all(), // Mencegah grafik keluar batas saat dizoom
      minX: _actMinX,
      maxX: _actMaxX,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final status = spot.y == 1 ? 'Aktif' : 'Diam';
              return LineTooltipItem(
                status,
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (_activityData.isEmpty ||
                  value.toInt() >= _activityData.length ||
                  value < 0)
                return const Text('');
                
              final range = _actMaxX - _actMinX;
              final displayInterval = (range / 5).ceil().clamp(1, 100);

              if (value.toInt() % displayInterval != 0) return const Text('');
              
              // Ambil waktu dari data aktivitas
              String timeLabel = '';
              try {
                final item = _activityData[value.toInt()];
                if (item['created_at'] != null) {
                  DateTime date = DateTime.parse(item['created_at']);
                  String format = range > 50 ? 'dd MMM' : 'HH:mm';
                  timeLabel = DateFormat(format).format(date);
                } else {
                  timeLabel = '${value.toInt()}';
                }
              } catch (_) {
                 timeLabel = '${value.toInt()}';
              }

              return SideTitleWidget(
                meta: meta,
                space: 10,
                child: Text(
                  timeLabel,
                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              String label = '';
              if (value.toInt() == 0)
                label = 'Diam';
              else if (value.toInt() == 1)
                label = 'Aktif';
              return Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 9),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _getActivitySpots(),
          isCurved: true,
          color: const Color(0xFF3949AB),
          barWidth: 3,
          isStrokeCapRound: true,
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF3949AB).withOpacity(0.1),
          ),
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }
}