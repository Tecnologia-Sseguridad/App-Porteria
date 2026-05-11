import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../widgets/result_modal.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImage();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _processImage();
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _isAnalyzing = true;
      _analysisProgress = 0.1;
    });

    final animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }
      setState(() {
        _analysisProgress = (_analysisProgress + 0.02).clamp(0.1, 0.95);
      });
    });

    final apiService = ApiService();
    final result = await apiService.scanMRZ(_selectedImage!);

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _analysisProgress = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (result['success'] == true) {
      final mrzData = result;
      
      final scanResult = ScanResult(
        nombres: mrzData['nombre']?.split(' ').first ?? '',
        apellidos: mrzData['nombre']?.split(' ').length > 1 
            ? mrzData['nombre']!.split(' ').skip(1).join(' ') 
            : '',
        rut: mrzData['rut'] ?? '',
        numeroCarnet: mrzData['serie'] ?? '',
        sexo: mrzData['sexo'] ?? 'M',
        nacionalidad: mrzData['nacionalidad'] ?? 'CHILENA',
        destino: '',
      );
      
      final blacklistCheck = await apiService.checkBlacklist(
        rut: scanResult.rut,
        usuarioId: apiService.usuarioId,
      );

      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (blacklistCheck['is_blacklist'] == true) {
        _showBlacklistAlert(scanResult, blacklistCheck['motivo'] ?? 'En lista negra');
      } else {
        _showResultModal(scanResult);
      }
    } else {
      setState(() => _isProcessing = false);
      _showError(result['message'] ?? 'No se pudo leer el carnet');
    }
  }

  void _showResultModal(ScanResult result) {
    final apiService = ApiService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ResultModal(
          result: result,
          organizationId: apiService.organizacionId,
          onSave: ({
            required String nombre,
            required String rut,
            required String serie,
            required String destino,
            String? patente,
            String? comentario,
          }) {
            Navigator.pop(context);
            _finalizarRegistro(
              nombre: nombre,
              rut: rut,
              serie: serie,
              destino: destino,
              patente: patente,
              comentario: comentario,
              sexo: result.sexo,
              nacionalidad: result.nacionalidad,
            );
          },
          onRetry: () {
            Navigator.pop(context);
            _pickImage();
          },
        ),
      ),
    );
  }

  void _finalizarRegistro({
    required String nombre,
    required String rut,
    required String serie,
    required String destino,
    String? patente,
    String? comentario,
    required String sexo,
    required String nacionalidad,
  }) async {
    final apiService = ApiService();
    setState(() => _isProcessing = true);
    
    final response = await apiService.registrarVisita(
      rut: rut,
      nombre: nombre,
      sexo: sexo == 'M' ? 'Masculino' : 'Femenino',
      serie: serie,
      nacionalidad: nacionalidad,
      destino: destino,
      patente: patente,
      comentario: comentario,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (response['success'] == true) {
      _showSuccess();
    } else {
      _showError(response['message'] ?? 'Error al registrar');
    }
  }

  void _showSuccess() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text('REGISTRADO', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    });
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showBlacklistAlert(ScanResult result, String motivo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ ACCESO DENEGADO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Persona en lista negra:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${result.nombres} ${result.apellidos}'),
            const SizedBox(height: 8),
            Text('RUT: ${result.rut}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Text('Motivo: $motivo', style: const TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              final apiService = ApiService();
              await apiService.registrarVisita(
                rut: result.rut,
                nombre: '${result.nombres} ${result.apellidos}'.trim(),
                sexo: result.sexo == 'M' ? 'Masculino' : 'Femenino',
                serie: result.numeroCarnet,
                nacionalidad: result.nacionalidad,
                destino: 'BLOQUEADO',
                esBlacklist: true,
              );
              
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('REGISTRAR Y VOLVER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_selectedImage != null)
            Positioned.fill(child: Image.file(_selectedImage!, fit: BoxFit.cover)),
          
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      _isAnalyzing ? 'PROCESANDO CARNET...' : 'GUARDANDO...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}