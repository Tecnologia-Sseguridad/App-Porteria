import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
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
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pickImage();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70,
        maxWidth: 1200,
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
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al abrir la cámara'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _isAnalyzing = true;
      _analysisProgress = 0.1;
    });

    // Animacion realista durante env\303\255o y procesamiento
    final animationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }
      setState(() {
        // Sube m\303\261s lento para dar sensaci\303\263n de progreso real
        _analysisProgress = (_analysisProgress + 0.02).clamp(0.1, 0.85);
      });
    });

    final apiService = ApiService();
    final result = await apiService.scanMRZ(_selectedImage!);

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _analysisProgress = 1.0;
      _isProcessing = false;
    });

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
      
      _showResultModal(scanResult);
    } else {
      final message = result['message'] ?? 'Error al procesar';
      if (result['is_blacklist'] == true) {
        _showBlacklistAlert(message);
      } else {
        _showError(message);
      }
    }
  }

  void _showResultModal(ScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ResultModal(
          result: result,
          onSave: (String destino, String? patente, String? comentario) {
            Navigator.pop(context);
            _showSuccessAndRegister(result, destino, patente, comentario);
          },
          onRetry: () {
            Navigator.pop(context);
            _pickImage();
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showBlacklistAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              '⚠️ BLOQUEADO',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage();
            },
            child: const Text(
              'ESCANEAR OTRO',
              style: TextStyle(color: Color(0xFFFFD600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndRegister(ScanResult result, String destino, String? patente, String? comentario) async {
    final apiService = ApiService();
    
    print('DEBUG _showSuccessAndRegister - rut: ${result.rut}');
    print('DEBUG _showSuccessAndRegister - nombre: ${result.nombres} ${result.apellidos}');
    print('DEBUG _showSuccessAndRegister - sexo: ${result.sexo}');
    print('DEBUG _showSuccessAndRegister - serie: ${result.numeroCarnet}');
    print('DEBUG _showSuccessAndRegister - nacionalidad: ${result.nacionalidad}');
    print('DEBUG _showSuccessAndRegister - destino: $destino');
    print('DEBUG _showSuccessAndRegister - patente: $patente');
    print('DEBUG _showSuccessAndRegister - comentario: $comentario');
    
    final response = await apiService.registrarVisita(
      rut: result.rut,
      nombre: '${result.nombres} ${result.apellidos}'.trim(),
      sexo: result.sexo == 'M' ? 'Masculino' : 'Femenino',
      serie: result.numeroCarnet,
      nacionalidad: result.nacionalidad,
      destino: destino,
      patente: patente,
      comentario: comentario,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      _showSuccessAnimation();
    } else {
      _showError(response['message'] ?? 'Error al registrar');
    }
  }

  void _showSuccessAnimation() {
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'VISITA REGISTRADA',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('ACEPTAR'),
                  ),
                ],
              ),
            ),
          );
        },
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
            Positioned.fill(
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
              ),
            ),
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: Icons.close,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ESCANEAR MRZ',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildCircleButton(
                      icon: Icons.refresh,
                      onTap: _pickImage,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _analysisProgress,
                              strokeWidth: 4,
                              backgroundColor: const Color(0xFF3A3A3A),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFD600),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.all(30),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD600).withOpacity(
                                    0.2 + (_pulseController.value * 0.2),
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isAnalyzing
                                      ? Icons.document_scanner
                                      : Icons.check_circle,
                                  size: 40,
                                  color: const Color(0xFFFFD600),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        _isAnalyzing ? 'Analizando...' : 'Procesando...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_analysisProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFFFFD600),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _analysisProgress,
                          backgroundColor: const Color(0xFF3A3A3A),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFD600),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Apunta la zona MRZ del carnet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}