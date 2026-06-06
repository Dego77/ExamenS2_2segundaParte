import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import 'mechanic_home_page.dart';
import 'mechanic_profile_page.dart';
import 'mechanic_history_page.dart';

class MechanicMainScreen extends StatefulWidget {
  const MechanicMainScreen({super.key});

  @override
  State<MechanicMainScreen> createState() => _MechanicMainScreenState();
}

class _MechanicMainScreenState extends State<MechanicMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final idTecnico = args?['id_tecnico'] ?? 1;

    final List<Widget> pages = [
      MechanicHomePage(idTecnico: idTecnico),
      MechanicHistoryPage(idTecnico: idTecnico),
      MechanicProfilePage(idTecnico: idTecnico),
    ];


    return Scaffold(
      body: pages[_currentIndex],
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
                icon: Icon(Icons.build_rounded),
                label: "Servicios",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded),
                label: "Historial",
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
