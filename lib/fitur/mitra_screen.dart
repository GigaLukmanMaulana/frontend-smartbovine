import 'package:flutter/material.dart';

class MitraScreen extends StatelessWidget {
  const MitraScreen({super.key});

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
          'Informasi Mitra',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Kapasitas & Fasilitas'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.pets, 'Populasi', '~200 Ekor (Sapi & Kerbau)'),
                    _buildInfoRow(Icons.category, 'Hewan', 'Sapi, Kambing, Kerbau'),
                    _buildInfoRow(Icons.home_work, 'Fasilitas', '7 Kandang'),
                    _buildInfoRow(Icons.merge_type, 'Jenis Sapi', 'Limosin, Brahman, Lokal PO'),
                    _buildInfoRow(Icons.group, 'Pekerja', '5 Orang (Pembagian tugas spesifik)'),
                  ]),
                  const SizedBox(height: 20),
                  
                  _buildSectionTitle('Fokus & Operasional'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.storefront, 'Fokus Usaha', 'Sapi transit (Jual beli & potong)'),
                    _buildInfoRow(Icons.schedule, 'Sistem Gembala', 'Dilepasliarkan pagi, kembali sore'),
                    _buildInfoRow(Icons.grass, 'Pakan', 'Rumput (Pagi & Sore)'),
                    _buildInfoRow(Icons.point_of_sale, 'Penjualan', 'Sapi kecil ke petani, sapi besar dipotong. Sedia untuk Idul Adha'),
                    _buildInfoRow(Icons.phone, 'Pemesanan', 'Melalui telepon'),
                  ]),
                  const SizedBox(height: 20),

                  _buildSectionTitle('Kesehatan Ternak'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.visibility, 'Pemeriksaan', 'Visual/Manual (berdasarkan pengalaman)'),
                    _buildInfoRow(Icons.warning_amber, 'Tanda Sakit', 'Tidak nafsu makan/minum, pencernaan terganggu'),
                    _buildInfoRow(Icons.medical_services, 'Penyakit Umum', 'Flu 3 hari, kejang, PMPA'),
                    _buildInfoRow(Icons.thermostat, 'Suhu Panas', 'Feses dapat menjadi mencret dan kering'),
                    _buildInfoRow(Icons.local_hospital, 'Dokter Hewan', 'Tersedia (tanpa jadwal tetap)'),
                  ]),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF00796B),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handshake,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dewa Kebo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Telah Berdiri Selama 35 Tahun',
              style: TextStyle(
                color: Color(0xFF00796B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF00796B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
