import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehiculos = [];

  @override
  void initState() {
    super.initState();
    _fetchVehiculos();
  }

  Future<void> _fetchVehiculos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final idCliente = authProvider.user?.id;
    if (idCliente == null) return;

    try {
      final response = await _apiService.getVehiculos(idCliente);
      if (response.statusCode == 200) {
        setState(() {
          _vehiculos = List<Map<String, dynamic>>.from(response.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddVehicleDialog() {
    final placaCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final anoCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    String selectedTransmision = "Automático";
    String selectedCombustible = "Gasolina";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Añadir Vehículo", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: placaCtrl, decoration: const InputDecoration(labelText: "Placa")),
                TextField(controller: marcaCtrl, decoration: const InputDecoration(labelText: "Marca")),
                TextField(controller: modeloCtrl, decoration: const InputDecoration(labelText: "Modelo")),
                TextField(controller: anoCtrl, decoration: const InputDecoration(labelText: "Año"), keyboardType: TextInputType.number),
                TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: "Color")),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTransmision,
                  decoration: const InputDecoration(labelText: "Transmisión"),
                  items: ["Automático", "Manual"]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedTransmision = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCombustible,
                  decoration: const InputDecoration(labelText: "Combustible"),
                  items: ["Gasolina", "Diésel", "Gas", "Eléctrico", "Híbrido"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCombustible = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (placaCtrl.text.isEmpty || marcaCtrl.text.isEmpty || modeloCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final idCliente = authProvider.user?.id;

                try {
                  await _apiService.registrarVehiculo(idCliente!, {
                    "placa": placaCtrl.text,
                    "marca": marcaCtrl.text,
                    "modelo": modeloCtrl.text,
                    "año": int.tryParse(anoCtrl.text) ?? 2020,
                    "color": colorCtrl.text,
                    "tipo_transmision": selectedTransmision,
                    "tipo_combustible": selectedCombustible
                  });
                  _fetchVehiculos();
                } catch (e) {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text("Guardar"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          "Mis Vehículos",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
        : _vehiculos.isEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.directions_car_rounded, size: 50, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 24),
                    Text("Aún no tienes vehículos", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddVehicleDialog,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text("Añadir Vehículo"),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _vehiculos.length,
              itemBuilder: (context, index) {
                final v = _vehiculos[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.directions_car_rounded, color: AppTheme.primaryBlue, size: 36),
                    title: Text("${v['marca']} ${v['modelo']}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: Text("Placa: ${v['placa']} • Color: ${v['color']}"),
                  ),
                );
              },
            ),
      floatingActionButton: _vehiculos.isNotEmpty 
        ? FloatingActionButton(onPressed: _showAddVehicleDialog, child: const Icon(Icons.add)) 
        : null,
    );
  }
}
