import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/navbar.dart';
import '../services/auth_service.dart';

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
  bool _isLoading = true;
  String selectedSapi = 'Sapi #1024 (Bessie)';
  final List<String> daftarSapi = [
    'Sapi #1024 (Bessie)',
    'Sapi #1025 (Clarabelle)',
    'Sapi #1026 (Angus)',
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // --- LOGIKA DATA DINAMIS ---
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      // Kirim parameter period ke Laravel
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/sapi-history?period=$_selectedPeriod',
            ),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _historyData = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  String _calculateStats(String type) {
    if (_historyData.isEmpty) return "0.0";
    List<double> values = _historyData
        .map((e) => double.parse(e['suhu'].toString()))
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

  List<FlSpot> _getSuhuLingkunganSpots() {
    return _historyData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        double.parse(entry.value['suhu_lingkungan'].toString()),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Riwayat & Laporan',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: primaryColor),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchHistory,
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
                                value: selectedSapi,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() => selectedSapi = newValue!);
                                },
                                items: daftarSapi.map<DropdownMenuItem<String>>(
                                  (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.pets,
                                            size: 16,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(value),
                                        ],
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        _buildCalendarButton(),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // --- Rentang Waktu ---
                    _buildRangeInfo(),
                    const SizedBox(height: 20),

                    // --- Card Grafik Utama ---
                    _buildChartCard(),
                    const SizedBox(height: 15),

                    // --- Card Aktivitas ---
                    _buildActivityCard(),
                    const SizedBox(height: 30),

                    // --- Tombol Unduh ---
                    _buildDownloadButton(),
                    const SizedBox(height: 10),
                    const Text(
                      'Format CSV & PDF tersedia untuk periode terpilih',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
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

  Widget _buildCalendarButton() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Icon(Icons.calendar_month_outlined, color: primaryColor),
          const CircleAvatar(radius: 4, backgroundColor: Colors.red),
        ],
      ),
    );
  }

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
                'Tren Suhu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  _buildLegendDot(Colors.green, 'Tubuh'),
                  const SizedBox(width: 10),
                  _buildLegendDot(Colors.grey, 'Lingkungan', isDashed: true),
                ],
              ),
            ],
          ),
          const Text(
            'Suhu Tubuh vs Lingkungan',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatInfo(
                'Maksimum',
                '${_calculateStats('max')}°C',
                Colors.red,
              ),
              _buildStatInfo(
                'Rata-rata',
                '${_calculateStats('avg')}°C',
                Colors.black,
              ),
              _buildStatInfo(
                'Minimum',
                '${_calculateStats('min')}°C',
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(height: 200, child: LineChart(sampleData())),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activityCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_run, color: primaryColor),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kondisi Aktivitas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _historyData.isEmpty
                      ? 'Memuat data...'
                      : 'Aktivitas normal terdeteksi berdasarkan data sensor terbaru.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.file_download_outlined, color: Colors.white),
        label: const Text(
          'Unduh Laporan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8D6E63),
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
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => primaryColor,
          getTooltipItems: (spots) => spots
              .map(
                (s) => LineTooltipItem(
                  '${s.y}°C',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              .toList(),
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
            getTitlesWidget: (value, meta) {
              if (_historyData.isEmpty ||
                  value.toInt() >= _historyData.length ||
                  value < 0)
                return const Text('');
              DateTime date = DateTime.parse(
                _historyData[value.toInt()]['created_at'],
              );
              return SideTitleWidget(
                meta: meta,
                space: 10,
                child: Text(
                  DateFormat('HH:mm').format(date),
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
        LineChartBarData(
          spots: _getSuhuLingkunganSpots().isEmpty
              ? [const FlSpot(0, 35)]
              : _getSuhuLingkunganSpots(),
          isCurved: true,
          color: Colors.grey.withOpacity(0.5),
          barWidth: 2,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}
