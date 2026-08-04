class UserModel {
  final int id;
  final String nik;
  final String username;
  final String nama;
  final String? email;
  final String? nomorWhatsapp;
  final String? unitKerja;
  final String role;
  final String? fotoProfil;
  final List<ManagedUnit> managesUnits; // <-- TAMBAHAN BARU

  UserModel({
    required this.id,
    required this.nik,
    required this.username,
    required this.nama,
    this.email,
    this.nomorWhatsapp,
    this.unitKerja,
    required this.role,
    this.fotoProfil,
    this.managesUnits = const [], // <-- TAMBAHAN BARU
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parse manages_units dari JSON
    List<ManagedUnit> managedUnits = [];
    if (json['manages_units'] != null && json['manages_units'] is List) {
      managedUnits = (json['manages_units'] as List)
          .map((unit) => ManagedUnit.fromJson(unit))
          .toList();
    }

    return UserModel(
      id: json['id'] ?? 0,
      nik: json['nik'] ?? '',
      username: json['username'] ?? '',
      nama: json['nama'] ?? '',
      email: json['email'],
      nomorWhatsapp: json['nomor_whatsapp'],
      unitKerja: json['unit_kerja'],
      role: json['role'] ?? 'staf',
      fotoProfil: json['foto_profil'],
      managesUnits: managedUnits, // <-- TAMBAHAN BARU
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nik': nik,
    'username': username,
    'nama': nama,
    'email': email,
    'nomor_whatsapp': nomorWhatsapp,
    'unit_kerja': unitKerja,
    'role': role,
    'foto_profil': fotoProfil,
    'manages_units': managesUnits.map((u) => u.toJson()).toList(),
  };

  // ===== HELPER METHODS =====

  bool get isSuperadmin => role == 'superadmin';
  bool get canAbsen => role != 'superadmin';

  bool get canValidasi =>
      role == 'kepala_unit' || role == 'hrd' || role == 'superadmin';

  // Role Manajemen (bisa kelola multi-unit)
  bool get isManajemen =>
      role == 'kepala_unit' || role == 'penanggung_jawab' || role == 'manajer';

  // Role Direktur (akses global)
  bool get isDirektur => role == 'direktur';

  // Role HRD
  bool get isHrd => role == 'hrd';

  // Akses Global (Direktur, HRD, atau Superadmin)
  bool get hasGlobalAccess => isDirektur || isHrd || isSuperadmin;

  // Cek apakah user punya unit yang dikelola
  bool get hasManagedUnits => managesUnits.isNotEmpty;

  // Dapatkan nama-nama unit yang dikelola (untuk ditampilkan)
  String get managedUnitsNames {
    if (managesUnits.isEmpty) return '-';
    return managesUnits.map((u) => u.namaUnit).join(', ');
  }
}

// Model untuk Unit yang Dikelola
class ManagedUnit {
  final int id;
  final String namaUnit;

  ManagedUnit({required this.id, required this.namaUnit});

  factory ManagedUnit.fromJson(Map<String, dynamic> json) {
    return ManagedUnit(id: json['id'] ?? 0, namaUnit: json['nama_unit'] ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id, 'nama_unit': namaUnit};
}
