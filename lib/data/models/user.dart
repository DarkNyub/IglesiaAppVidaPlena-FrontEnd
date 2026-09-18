class User {
  final int id;
  final int memberId;
  final String username;
  final String systemRole;
  final String token;
  final DateTime expiresAt;
  Map<String, dynamic>? extraData; // <--- Nuevo: Para traer el diseño de la BD
  final String FirstName;
  final String LastName;
  final String? photoUrl;

  User({
    required this.id,
    required this.memberId,
    required this.username,
    required this.systemRole,
    required this.token,
    required this.expiresAt,
    this.extraData,
    required this.FirstName,
    required this.LastName,
    this.photoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['userId'] ?? 0,
      memberId: json['memberId'] ?? 0,
      username: json['username'] ?? '',
      systemRole: json['systemRole'] ?? 'User',
      token: json['token'] ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : DateTime.now().add(const Duration(hours: 12)),
      extraData: json['extraData'], // <--- Mapeamos el campo JSONB
      FirstName: json['FirstName'] ?? '',
      LastName: json['LastName'] ?? '',
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'memberId': memberId,
      'username': username,
      'systemRole': systemRole,
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
      'extraData': extraData,
      'FirstName': FirstName,
      'LastName': LastName,
      'photoUrl': photoUrl,
    };
  }
}
