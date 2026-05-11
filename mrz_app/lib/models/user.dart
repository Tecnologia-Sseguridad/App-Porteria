class User {
  final int id;
  final String name;
  final String email;
  final String token;
  final int organizacionId;
  final List<String> organizaciones;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.organizacionId = 0,
    this.organizaciones = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['email']?.toString().split('@').first ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? '',
      organizacionId: json['organizacion_id'] ?? 0,
      organizaciones: (json['organizaciones'] as List?)
              ?.map((o) => o is String ? o : o['nombre']?.toString() ?? '')
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
      'organizacion_id': organizacionId,
      'organizaciones': organizaciones,
    };
  }
}