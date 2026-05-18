import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';

class VisitaDetalleScreen extends StatefulWidget {
  final ScanResult visita;
  final DateTime fechaEntradaReal;

  const VisitaDetalleScreen({
    super.key,
    required this.visita,
    required this.fechaEntradaReal,
  });

  @override
  State<VisitaDetalleScreen> createState() => _VisitaDetalleScreenState();
}

class _VisitaDetalleScreenState extends State<VisitaDetalleScreen> {
  final ApiService _apiService = ApiService();
  late ScanResult _visita;
  Timer? _timer;
  String _tiempoDentro = '';
  bool _isLoading = false;
  late DateTime _fechaEntrada;

  @override
  void initState() {
    super.initState();
    _visita = widget.visita;
    _fechaEntrada = widget.fechaEntradaReal;
    _iniciarContador();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarContador() {
    _calcularTiempo();
    if (_visita.horaSalida == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _calcularTiempo();
      });
    }
  }

  void _calcularTiempo() {
    if (!mounted) return;

    DateTime ahora = DateTime.now();
    DateTime entrada = _fechaEntrada;
    
    if (_visita.horaSalida != null && _visita.horaSalida!.isNotEmpty) {
      final diferencia = ahora.difference(entrada);
      final horas = diferencia.inHours;
      final minutos = diferencia.inMinutes % 60;
      
      setState(() {
        _tiempoDentro = '${horas}h ${minutos}min';
      });
    } else {
      final diferencia = ahora.difference(entrada);
      final horas = diferencia.inHours;
      final minutos = diferencia.inMinutes % 60;
      final segundos = diferencia.inSeconds % 60;

      setState(() {
        _tiempoDentro = '${horas}h ${minutos}m ${segundos}s';
      });
    }
  }

  Future<void> _marcarSalida() async {
    if (_visita.id == null) return;

    setState(() => _isLoading = true);
    final success = await _apiService.marcarSalida(_visita.id!);
    setState(() => _isLoading = false);

    if (success && mounted) {
      HapticFeedback.mediumImpact();
      _timer?.cancel();
      final horaSalida = DateTime.now();
      setState(() {
        _visita = _visita.copyWith(
          horaSalida: '${horaSalida.hour.toString().padLeft(2, '0')}:${horaSalida.minute.toString().padLeft(2, '0')}',
        );
      });
      _calcularTiempo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Salida registrada correctamente'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al registrar salida'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _eliminarRegistro() async {
    if (_visita.id == null) return;

    final TextEditingController motivoController = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 12),
            Text('Eliminar Registro', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingrese el motivo de la eliminación:',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: InputDecoration(
                hintText: 'Ej: Cliente se fue sin registrarse',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, motivoController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (motivo == null || motivo.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.eliminarVisita(_visita.id!, motivo: motivo);
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registro eliminado'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneSalida = _visita.horaSalida != null && _visita.horaSalida!.isNotEmpty;
    final tieneBlacklist = _visita.esBlacklist;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: Text(tieneSalida ? 'Detalles de Visita' : 'Visita en Curso'),
        actions: [
          if (tieneBlacklist)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 14),
                  SizedBox(width: 4),
                  Text('BLOQUEADO', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!tieneSalida) _buildTimerCard(),
            const SizedBox(height: 20),
            _buildProfileCard(tieneBlacklist),
            const SizedBox(height: 20),
            _buildDetailsList(),
            const SizedBox(height: 32),
            _buildActionButtons(tieneSalida),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'TIEMPO TRANSCURRIDO',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            _tiempoDentro,
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool tieneBlacklist) {
    final bool isMale = _visita.sexo == 'M' || _visita.sexo == 'Masculino';
    final Color color = tieneBlacklist ? const Color(0xFFEF4444) : (isMale ? const Color(0xFF6366F1) : const Color(0xFFEC4899));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              tieneBlacklist ? Icons.block_rounded : Icons.person_rounded,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_visita.nombres} ${_visita.apellidos}',
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _visita.rut,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_rounded, color: Color(0xFF6366F1), size: 18),
              SizedBox(width: 10),
              Text('INFORMACIÓN', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(Icons.meeting_room_rounded, 'Destino', _visita.destino),
          _buildDetailRow(Icons.pin_rounded, 'N° Serie', _visita.numeroCarnet.isNotEmpty ? _visita.numeroCarnet : 'Sin dato'),
          _buildDetailRow(Icons.public_rounded, 'Nacionalidad', _visita.nacionalidad),
          if (_visita.patente != null && _visita.patente!.isNotEmpty)
            _buildDetailRow(Icons.directions_car_rounded, 'Patente', _visita.patente!),
          if (_visita.comentarios != null && _visita.comentarios!.isNotEmpty)
            _buildDetailRow(Icons.notes_rounded, 'Comentario', _visita.comentarios!),
          const Divider(height: 32, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              Expanded(child: _buildDetailRow(Icons.login_rounded, 'Entrada', _visita.horaEntrada ?? '--:--', compact: true)),
              if (_visita.horaSalida != null && _visita.horaSalida!.isNotEmpty)
                Expanded(child: _buildDetailRow(Icons.logout_rounded, 'Salida', _visita.horaSalida!, compact: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF64748B), size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool tieneSalida) {
    return Column(
      children: [
        if (!tieneSalida)
          ElevatedButton(
            onPressed: _isLoading ? null : _marcarSalida,
            child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.exit_to_app_rounded),
                      SizedBox(width: 12),
                      Text('REGISTRAR SALIDA'),
                    ],
                  ),
          ),
        if (!tieneSalida) const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _isLoading ? null : _eliminarRegistro,
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
          label: const Text('ELIMINAR REGISTRO', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, letterSpacing: 1)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
          ),
        ),
      ],
    );
  }
}