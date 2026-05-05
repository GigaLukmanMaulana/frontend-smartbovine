import 'package:flutter/material.dart';

// PASTIKAN PATH INI BENAR SESUAI FOLDER LU
import '../fitur/dashboard.dart';
import '../fitur/maps_sapi.dart';
import '../fitur/suhu_sapi.dart'; 
import '../fitur/kelolaiot.dart';
class CustomNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected; // Gue balikin jadi required

  const CustomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected, // Tambahin required di sini
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home_outlined, 'Beranda', 0),
          _buildNavItem(context, Icons.map_outlined, 'Peta', 1),
          const SizedBox(width: 40), // Spasi FAB
          _buildNavItem(context, Icons.sensors, 'Perangkat', 2),
          _buildNavItem(context, Icons.history, 'Riwayat', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index) {
    bool isSelected = selectedIndex == index;
    return InkWell(
      onTap: () {
        onItemSelected(index);
        if (index == selectedIndex) return;

        Widget targetScreen;
        switch (index) {
          case 0:
            targetScreen = const Dashboard();
            break;
          case 1:
            targetScreen = const MapSapiScreen();
            break;
          case 2:
            // Karena di file suhu_sapi.dart nama class lu adalah ReportScreen, 
            // kita panggil ReportScreen(). Hapus 'const' jika error berlanjut.
            targetScreen = const KelolaIotScreen(); 
            break;
          case 3:
            targetScreen = const ReportScreen();
            break;
          default:
            targetScreen = const Dashboard();
        }

        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
          (route) => false,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF2E7D32) : Colors.grey),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? const Color(0xFF2E7D32) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}