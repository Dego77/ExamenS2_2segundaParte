import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pagos = [];

  @override
  void initState() {
    super.initState();
    _fetchPagos();
  }

  Future<void> _fetchPagos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final idCliente = authProvider.user?.id;
    if (idCliente == null) return;

    try {
      final response = await _apiService.getHistorialPagos(idCliente);
      if (response.statusCode == 200) {
        setState(() {
          _pagos = List<Map<String, dynamic>>.from(response.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          "Reporte de Pagos",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
        : _pagos.isEmpty
          ? SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(color: AppTheme.secondaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_long_rounded, size: 50, color: AppTheme.secondaryGreen),
                      ),
                      const SizedBox(height: 24),
                      Text("Sin pagos recientes", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pagos.length,
              itemBuilder: (context, index) {
                final p = _pagos[index];
                final bool isPending = p['estado'] == 'Pendiente';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    onTap: () {
                      if (isPending && p['id_incidente'] != null) {
                        Navigator.pushNamed(
                          context, 
                          '/checkout', 
                          arguments: {'id_incidente': p['id_incidente']}
                        ).then((_) => _fetchPagos());
                      }
                    },
                    leading: Icon(
                      Icons.payment_rounded, 
                      color: isPending ? AppTheme.accentYellow : AppTheme.secondaryGreen, 
                      size: 36
                    ),
                    title: Text("Bs. ${p['monto']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text("🔧 ${p['problema'] ?? 'Avería'} • ${p['taller']}\n📅 ${p['fecha']}"),
                    isThreeLine: true,
                    trailing: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isPending ? AppTheme.accentYellow : AppTheme.secondaryGreen).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                        p['estado'] ?? 'Completado', 
                        style: GoogleFonts.inter(
                          color: isPending ? const Color(0xFFB45309) : AppTheme.secondaryGreen, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                        )
                      ),
                    ),
                  ),
                );
              },
            ),

    );
  }
}
