import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';

class ResultModal extends StatefulWidget {
  final ScanResult result;
  final Function({
    required String nombre,
    required String rut,
    required String serie,
    required String destino,
    String? patente,
    String? comentario,
  }) onSave;
  final VoidCallback onRetry;
  final int organizationId;

  const ResultModal({
    super.key,
    required this.result,
    required this.onSave,
    required this.onRetry,
    required this.organizationId,
  });

  @override
  State<ResultModal> createState() => _ResultModalState();
}

class _ResultModalState extends State<ResultModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  late TextEditingController _nombreCompletoController;
  late TextEditingController _rutController;
  late TextEditingController _carnetController;
  late TextEditingController _nacionalidadController;
  late TextEditingController _destinoController;
  late TextEditingController _patenteController;
  late TextEditingController _comentariosController;
  final ValueNotifier<bool> _canSaveNotifier = ValueNotifier<bool>(false);
  
  List<Map<String, dynamic>> _destinos = [];
  bool _cargandoDestinos = true;
  bool _mostrarDropdown = false;

  @override
  void initState() {
    super.initState();
    _cargarDestinos();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _rutController = TextEditingController(text: widget.result.rut);
    _carnetController = TextEditingController(text: widget.result.numeroCarnet);
    _nacionalidadController = TextEditingController(text: widget.result.nacionalidad);
    _destinoController = TextEditingController();
    _patenteController = TextEditingController();
    _comentariosController = TextEditingController();
    
    final String nombreCompleto = '${widget.result.nombres} ${widget.result.apellidos}'.trim();
    _nombreCompletoController = TextEditingController(text: nombreCompleto);

    _destinoController.addListener(_validate);
    _rutController.addListener(_validate);
    _nombreCompletoController.addListener(_validate);
    _carnetController.addListener(_validate);
  }
  
  Future<void> _cargarDestinos() async {
    final apiService = ApiService();
    try {
      if (widget.organizationId > 0) {
        final destinos = await apiService.getDestinos(widget.organizationId);
        if (mounted) {
          setState(() {
            _destinos = destinos;
            _cargandoDestinos = false;
            _mostrarDropdown = destinos.isNotEmpty;
          });
        }
      } else {
        if (mounted) setState(() => _cargandoDestinos = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoDestinos = false);
    }
  }

  void _validate() {
    setState(() {
      _canSaveNotifier.value = 
        _destinoController.text.trim().isNotEmpty && 
        _rutController.text.trim().isNotEmpty &&
        _nombreCompletoController.text.trim().isNotEmpty &&
        _carnetController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nombreCompletoController.dispose();
    _rutController.dispose();
    _carnetController.dispose();
    _nacionalidadController.dispose();
    _destinoController.dispose();
    _canSaveNotifier.dispose();
    _patenteController.dispose();
    _comentariosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'REVISAR INFORMACIÓN',
              style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Confirma los datos antes de registrar',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildInputField(label: 'Nombre Completo *', controller: _nombreCompletoController, icon: Icons.person_rounded),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInputField(label: 'RUT *', controller: _rutController, icon: Icons.badge_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInputField(label: 'N° Serie *', controller: _carnetController, icon: Icons.pin_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_cargandoDestinos)
                      const LinearProgressIndicator()
                    else if (_mostrarDropdown)
                      _buildDestinoDropdown()
                    else
                      _buildInputField(label: 'Destino *', controller: _destinoController, icon: Icons.meeting_room_rounded),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInputField(label: 'Patente', controller: _patenteController, icon: Icons.directions_car_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInputField(label: 'Nacionalidad', controller: _nacionalidadController, icon: Icons.public_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(label: 'Comentario', controller: _comentariosController, icon: Icons.notes_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onRetry,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('REINTENTAR', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canSaveNotifier.value 
                        ? () => widget.onSave(
                            nombre: _nombreCompletoController.text.trim(),
                            rut: _rutController.text.trim(),
                            serie: _carnetController.text.trim(),
                            destino: _destinoController.text.trim(),
                            patente: _patenteController.text.trim().isEmpty ? null : _patenteController.text.trim(),
                            comentario: _comentariosController.text.trim().isEmpty ? null : _comentariosController.text.trim(),
                          ) 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text('REGISTRAR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller, required IconData icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        isDense: true,
      ),
    );
  }

  Widget _buildDestinoDropdown() {
    return DropdownButtonFormField<String>(
      value: _destinoController.text.isEmpty ? null : _destinoController.text,
      dropdownColor: Colors.white,
      decoration: const InputDecoration(
        labelText: 'Seleccionar Destino *',
        prefixIcon: Icon(Icons.meeting_room_rounded, color: Color(0xFF64748B), size: 20),
        isDense: true,
      ),
      items: _destinos.map((d) {
        return DropdownMenuItem<String>(
          value: d['nombre'].toString(),
          child: Text(d['nombre'].toString(), style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          _destinoController.text = val;
          _validate();
        }
      },
    );
  }
}