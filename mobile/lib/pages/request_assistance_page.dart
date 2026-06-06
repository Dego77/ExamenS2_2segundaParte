import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

class RequestAssistancePage extends StatefulWidget {
  const RequestAssistancePage({super.key});

  @override
  State<RequestAssistancePage> createState() => _RequestAssistancePageState();
}

class _RequestAssistancePageState extends State<RequestAssistancePage> {
  final _descriptionController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _apiService = ApiService();

  int? _selectedVehiculoId;
  List<Map<String, dynamic>> _userVehiculos = [];
  bool _isLoadingVehiculos = true;

  String _locationStatus = "Obteniendo ubicación...";
  String? _audioPath;
  String? _photoPath;
  bool _isRecording = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchVehiculos();
  }

  Future<void> _fetchVehiculos() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final idCliente = authProvider.user?.id;
    if (idCliente == null) return;

    try {
      final response = await _apiService.getVehiculos(idCliente);
      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> vehiculos = List<Map<String, dynamic>>.from(response.data);
        setState(() {
          _userVehiculos = vehiculos;
          _isLoadingVehiculos = false;
          if (vehiculos.isNotEmpty) {
            _selectedVehiculoId = vehiculos.first['id_vehiculo'];
          }
        });
      }
    } catch (e) {
      setState(() => _isLoadingVehiculos = false);
    }
  }

  void _showAddVehicleDialog() {
    final placaCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final anoCtrl = TextEditingController();
    final colorCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (placaCtrl.text.isEmpty || marcaCtrl.text.isEmpty || modeloCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoadingVehiculos = true);
              
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final idCliente = authProvider.user?.id;

              try {
                await _apiService.registrarVehiculo(idCliente!, {
                  "placa": placaCtrl.text,
                  "marca": marcaCtrl.text,
                  "modelo": modeloCtrl.text,
                  "año": int.tryParse(anoCtrl.text) ?? 2020,
                  "color": colorCtrl.text,
                  "tipo_transmision": "Automático",
                  "tipo_combustible": "Gasolina"
                });
                _fetchVehiculos();
              } catch (e) {
                setState(() => _isLoadingVehiculos = false);
              }
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Permisos de ubicación denegados permanentemente.");
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationStatus =
              "Ubicación capturada: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _latitude = -16.5000;
          _longitude = -68.1500;
          _locationStatus = "Ubicación Simulada (Pruebas): -16.5000, -68.1500";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo obtener el GPS real. Usando ubicación de prueba."),
            backgroundColor: Colors.orange,
          )
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _photoPath = image.path;
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });
      }
    }
  }

  Future<void> _sendEmergencyRequest() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Esperando ubicación GPS...")),
      );
      return;
    }


    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final idCliente = authProvider.user?.id;

    if (_selectedVehiculoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes registrar y seleccionar un vehículo.")),
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context, 
      '/searching',
      arguments: {
        'idCliente': idCliente,
        'idVehiculo': _selectedVehiculoId,
        'latitud': _latitude,
        'longitud': _longitude,
        'descripcion': _descriptionController.text,
        'audioPath': _audioPath,
        'fotoPath': _photoPath,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Solicitar Auxilio",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Diagnóstico Inteligente",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          "Sube evidencias del problema. Nuestra IA analizará la situación y encontrará al especialista adecuado en segundos.",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              "Selecciona tu vehículo",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _isLoadingVehiculos
                ? const CircularProgressIndicator(color: AppTheme.primaryBlue)
                : _userVehiculos.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("No tienes vehículos registrados.", style: GoogleFonts.inter(color: AppTheme.emergencyRed)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _showAddVehicleDialog,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text("Registrar Vehículo ahora"),
                          ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedVehiculoId,
                            isExpanded: true,
                            items: _userVehiculos.map((v) {
                              return DropdownMenuItem<int>(
                                value: v['id_vehiculo'],
                                child: Text("${v['marca']} ${v['modelo']} (${v['placa']})"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedVehiculoId = val;
                              });
                            },
                          ),
                        ),
                      ),
            const SizedBox(height: 32),

            Text(
              "Audio (Opcional pero recomendado)",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _toggleRecording,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? AppTheme.emergencyRed.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRecording
                        ? AppTheme.emergencyRed
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? AppTheme.emergencyRed.withOpacity(0.1)
                            : AppTheme.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isRecording
                            ? AppTheme.emergencyRed
                            : AppTheme.primaryBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? "Grabando... Toca para detener"
                          : (_audioPath != null
                                ? "Audio capturado correctamente"
                                : "Toca para hablar"),
                      style: GoogleFonts.inter(
                        color: _isRecording
                            ? AppTheme.emergencyRed
                            : AppTheme.textGray,
                        fontSize: 13,
                        fontWeight: _isRecording || _audioPath != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "Fotos de la alerta o avería",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _takePhoto,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: _photoPath != null
                      ? AppTheme.secondaryGreen.withOpacity(0.1)
                      : AppTheme.accentYellow.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _photoPath != null
                        ? AppTheme.secondaryGreen
                        : AppTheme.accentYellow.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _photoPath != null
                          ? Icons.check_circle_rounded
                          : Icons.add_a_photo_rounded,
                      color: _photoPath != null
                          ? AppTheme.secondaryGreen
                          : AppTheme.accentYellow,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _photoPath != null
                          ? "Foto capturada correctamente"
                          : "Toma una foto de la falla",
                      style: GoogleFonts.inter(
                        color: _photoPath != null
                            ? AppTheme.secondaryGreen
                            : AppTheme.accentYellow,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "Descripción breve",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Ej. Mi auto no enciende frente al parque...",
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.secondaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationStatus,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _sendEmergencyRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 10,
                shadowColor: AppTheme.primaryBlue.withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    "¡Pedir Auxilio Ahora!",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
