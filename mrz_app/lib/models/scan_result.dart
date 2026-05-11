class ScanResult {
  final int? id;
  final String nombres;
  final String apellidos;
  final String rut;
  final String numeroCarnet;
  final String sexo;
  final String nacionalidad;
  final String destino;
  final String? patente;
  final String? comentarios;
  final String? fechaNacimiento;
  final String? fechaExpiracion;
  final DateTime fechaScan;
  final String? horaEntrada;
  final String? horaSalida;
  final DateTime? fechaEntrada;
  final bool isSynced;
  final bool esBlacklist;

  ScanResult({
    this.id,
    required this.nombres,
    required this.apellidos,
    required this.rut,
    required this.numeroCarnet,
    required this.sexo,
    required this.nacionalidad,
    required this.destino,
    this.patente,
    this.comentarios,
    this.fechaNacimiento,
    this.fechaExpiracion,
    DateTime? fechaScan,
    this.horaEntrada,
    this.horaSalida,
    this.fechaEntrada,
    this.isSynced = false,
    this.esBlacklist = false,
  }) : fechaScan = fechaScan ?? DateTime.now();

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    DateTime? fechaEntrada;
    try {
      final fechaEntStr = json['fecha_entrada'] as String?;
      if (fechaEntStr != null && fechaEntStr.isNotEmpty) {
        fechaEntrada = DateTime.parse(fechaEntStr);
      }
    } catch (_) {}
    
    return ScanResult(
      id: json['id'],
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      rut: json['rut'] ?? '',
      numeroCarnet: json['numero_carnet'] ?? '',
      sexo: json['sexo'] ?? '',
      nacionalidad: json['nacionalidad'] ?? '',
      destino: json['destino'] ?? '',
      patente: json['patente'],
      comentarios: json['comentarios'],
      fechaNacimiento: json['fecha_nacimiento'],
      fechaExpiracion: json['fecha_expiracion'],
      fechaScan: json['fecha_scan'] != null 
          ? DateTime.parse(json['fecha_scan']) 
          : DateTime.now(),
      horaEntrada: json['hora_entrada'],
      horaSalida: json['hora_salida'],
      fechaEntrada: fechaEntrada,
      isSynced: json['is_synced'] ?? false,
      esBlacklist: json['es_blacklist'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombres': nombres,
      'apellidos': apellidos,
      'rut': rut,
      'numero_carnet': numeroCarnet,
      'sexo': sexo,
      'nacionalidad': nacionalidad,
      'destino': destino,
      'patente': patente,
      'comentarios': comentarios,
      'fecha_nacimiento': fechaNacimiento,
      'fecha_expiracion': fechaExpiracion,
      'fecha_scan': fechaScan.toIso8601String(),
      'hora_entrada': horaEntrada,
      'hora_salida': horaSalida,
      'fecha_entrada': fechaEntrada?.toIso8601String(),
      'is_synced': isSynced,
      'es_blacklist': esBlacklist,
    };
  }

  ScanResult copyWith({
    int? id,
    String? nombres,
    String? apellidos,
    String? rut,
    String? numeroCarnet,
    String? sexo,
    String? nacionalidad,
    String? destino,
    String? patente,
    String? comentarios,
    String? fechaNacimiento,
    String? fechaExpiracion,
    DateTime? fechaScan,
    String? horaEntrada,
    String? horaSalida,
    DateTime? fechaEntrada,
    bool? isSynced,
    bool? esBlacklist,
  }) {
    return ScanResult(
      id: id ?? this.id,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      rut: rut ?? this.rut,
      numeroCarnet: numeroCarnet ?? this.numeroCarnet,
      sexo: sexo ?? this.sexo,
      nacionalidad: nacionalidad ?? this.nacionalidad,
      destino: destino ?? this.destino,
      patente: patente ?? this.patente,
      comentarios: comentarios ?? this.comentarios,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      fechaScan: fechaScan ?? this.fechaScan,
      horaEntrada: horaEntrada ?? this.horaEntrada,
      horaSalida: horaSalida ?? this.horaSalida,
      fechaEntrada: fechaEntrada ?? this.fechaEntrada,
      isSynced: isSynced ?? this.isSynced,
      esBlacklist: esBlacklist ?? this.esBlacklist,
    );
  }
}