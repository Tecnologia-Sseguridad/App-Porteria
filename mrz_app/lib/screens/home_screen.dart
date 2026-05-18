import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/session_expired_dialog.dart';
import 'scanner_screen.dart';
import 'login_screen.dart';
import 'visita_detalle_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<ScanResult> _scans = [];
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  int _totalHoy = 0;
  int _dentroEdificio = 0;
  int _salieronHoy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSessionListener();
    _initAndValidateSession();
  }

  Future<void> _initAndValidateSession() async {
    await _apiService.restoreSession();
    
    if (_apiService.session == null) {
      if (mounted) {
        showSessionExpiredDialog(context);
      }
      return;
    }

    final isValid = await _apiService.validateSession();
    if (!isValid && _apiService.session == null) {
      if (mounted) {
        showSessionExpiredDialog(context);
      }
      return;
    }

    _loadScans();
  }

  void _setupSessionListener() {
    _apiService.onSessionExpired = () {
      if (mounted) {
        showSessionExpiredDialog(context);
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiService.onSessionExpired = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_apiService.session != null) {
        _refreshOnResume();
      } else {
        showSessionExpiredDialog(context);
      }
    }
  }

  Future<void> _refreshOnResume() async {
    // Verificar expiración local primero
    if (_apiService.isSessionExpiredLocal) {
      showSessionExpiredDialog(context);
      return;
    }

    // Trigger el refresh igual (como si el usuario hiciera pull-to-refresh)
    // Esto causará que se muestren los datos y si hay error 401, se detectará
    await _loadScans();
  }

  Future<void> _validateSessionOnResume() async {
    if (_apiService.session == null) {
      showSessionExpiredDialog(context);
      return;
    }

    final isValid = await _apiService.validateSessionSimple();
    if (!isValid && _apiService.session == null) {
      if (mounted) showSessionExpiredDialog(context);
    }
  }

  Future<void> _loadScans() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getMisVisitasHoy();

    if (result['session_expired'] == true) {
      if (mounted) {
        showSessionExpiredDialog(context);
      }
      return;
    }

    if (result['success'] == true) {
      final contadores = result['contadores'] as Map<String, dynamic>? ?? {};
      final visitas = result['visitas'] as List<dynamic>? ?? [];

      _totalHoy = contadores['total_hoy'] ?? 0;
      _dentroEdificio = contadores['dentro_edificio'] ?? 0;
      _salieronHoy = contadores['salieron_hoy'] ?? 0;

      _scans = visitas.map((v) {
        DateTime? fechaEnt;
        try {
          final fe = v['fecha_entrada'] as String?;
          if (fe != null && fe.isNotEmpty) fechaEnt = DateTime.parse(fe);
        } catch (_) {}
        return ScanResult(
          id: v['id'] as int?,
          nombres: (v['nombre'] as String? ?? '').split(' ').first,
          apellidos: (v['nombre'] as String? ?? '').replaceAll(RegExp(r'^[^ ]+ '), ''),
          rut: v['rut'] as String? ?? '',
          numeroCarnet: v['serie_carnet'] as String? ?? '',
          sexo: v['sexo'] as String? ?? 'M',
          nacionalidad: 'CHL',
          destino: v['destino'] as String? ?? '',
          fechaScan: DateTime.now(),
          horaEntrada: v['hora_entrada'] as String?,
          horaSalida: v['hora_salida'] as String?,
          fechaEntrada: fechaEnt,
          esBlacklist: v['es_blacklist'] as bool? ?? false,
        );
      }).toList();
    }
    setState(() => _isLoading = false);
  }

  void _openScanner() async {
    HapticFeedback.lightImpact();
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
    _loadScans();
  }

  void _logout() {
    _apiService.logout();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('CONTROL DE ACCESO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF1E293B)),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadScans,
        color: const Color(0xFF1E293B),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoCard(),
                    const SizedBox(height: 20),
                    Text(
                      'Resumen del día',
                      style: TextStyle(color: const Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Últimos escaneos',
                      style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _loadScans,
                      child: const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_scans.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('No hay registros hoy')))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildScanCard(_scans[index]),
                    childCount: _scans.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('ESCANEAR'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = (constraints.maxWidth - 12) / 2;
        return Column(
          children: [
            Row(
              children: [
                _buildStatItem('TOTAL HOY', '$_totalHoy', Icons.group_rounded, const Color(0xFF1E293B), width),
                const SizedBox(width: 12),
                _buildStatItem('DENTRO', '$_dentroEdificio', Icons.login_rounded, const Color(0xFF059669), width),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem('SALIERON', '$_salieronHoy', Icons.logout_rounded, const Color(0xFFD97706), width),
                const SizedBox(width: 12),
                _buildStatItem('PENDIENTES', '${_totalHoy - _salieronHoy}', Icons.pending_actions_rounded, const Color(0xFF475569), width),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    final nombreMostrar = widget.user.name.isNotEmpty ? widget.user.name : widget.user.email.split('@').first;
    final sedeMostrar = widget.user.organizaciones.isNotEmpty ? widget.user.organizaciones.first : 'Sin sede asignada';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_circle_rounded, color: Color(0xFF475569), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreMostrar,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      sedeMostrar,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(ScanResult scan) {
    final isBlacklist = scan.esBlacklist;
    final tieneSalida = scan.horaSalida != null && scan.horaSalida!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isBlacklist ? Colors.red[200]! : const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisitaDetalleScreen(
                visita: scan,
                fechaEntradaReal: scan.fechaEntrada ?? DateTime.now(),
              ),
            ),
          ).then((_) => _loadScans());
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isBlacklist ? Colors.red[50] : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isBlacklist ? Icons.block_rounded : Icons.person_outline_rounded,
            color: isBlacklist ? Colors.red : const Color(0xFF475569),
          ),
        ),
        title: Text(
          '${scan.nombres} ${scan.apellidos}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        subtitle: Text('RUT: ${scan.rut} • ${scan.horaEntrada ?? ''}'),
        trailing: Icon(
          tieneSalida ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: tieneSalida ? Colors.green : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}