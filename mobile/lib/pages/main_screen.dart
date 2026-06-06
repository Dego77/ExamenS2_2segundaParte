import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'vehicles_page.dart';
import 'payments_page.dart';
import 'tracking_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const VehiclesPage(),
    const TrackingPage(), // Temporarily tracking page for Asistencias
    const PaymentsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryBlue,
            unselectedItemColor: AppTheme.textGray.withOpacity(0.5),
            selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: "Inicio",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_car_rounded),
                label: "Vehículos",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.build_circle_rounded),
                label: "Asistencia",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.payment_rounded),
                label: "Pagos",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: "Perfil",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
