class Member {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? document;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? birthDate;

  // ExtraData viene como un JSON dinámico desde C#
  final Map<String, dynamic>? extraData;

  // Auditoría
  final bool isDeleted;

  // Usuario vinculado (si tiene cuenta de login)
  final MemberLinkedUser? linkedUser;
  final bool hasUserAccount;

  // Roles en las diferentes estructuras
  final List<MemberRole> roles;
  final List<String> rolesSummary;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.document,
    this.phone,
    this.email,
    this.address,
    this.birthDate,
    this.extraData,
    required this.isDeleted,
    this.linkedUser,
    required this.hasUserAccount,
    required this.roles,
    required this.rolesSummary,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      document: json['document'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'])
          : null,
      extraData: json['extraData'],
      isDeleted: json['isDeleted'] ?? false,

      linkedUser: json['linkedUser'] != null
          ? MemberLinkedUser.fromJson(json['linkedUser'])
          : null,

      hasUserAccount: json['hasUserAccount'] ?? false,

      roles:
          (json['roles'] as List?)
              ?.map((r) => MemberRole.fromJson(r))
              .toList() ??
          [],

      rolesSummary:
          (json['rolesSummary'] as List?)?.map((s) => s.toString()).toList() ??
          [],
    );
  }
}

// --- CLASES AUXILIARES PARA LOS OBJETOS ANIDADOS ---

class MemberLinkedUser {
  final int id;
  final String username;

  MemberLinkedUser({required this.id, required this.username});

  factory MemberLinkedUser.fromJson(Map<String, dynamic> json) {
    return MemberLinkedUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
    );
  }
}

class MemberRole {
  final int organizationStructureId;
  final String organizationName;
  final int churchFunctionRoleId;
  final String roleName;

  MemberRole({
    required this.organizationStructureId,
    required this.organizationName,
    required this.churchFunctionRoleId,
    required this.roleName,
  });

  factory MemberRole.fromJson(Map<String, dynamic> json) {
    return MemberRole(
      organizationStructureId: json['organizationStructureId'] ?? 0,
      organizationName: json['organizationName'] ?? '',
      churchFunctionRoleId: json['churchFunctionRoleId'] ?? 0,
      roleName: json['roleName'] ?? '',
    );
  }
}
