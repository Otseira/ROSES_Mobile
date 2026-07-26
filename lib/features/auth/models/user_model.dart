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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
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
  };

  bool get isSuperadmin => role == 'superadmin';
  bool get canAbsen => role != 'superadmin';
  bool get canValidasi =>
      role == 'kepala_unit' || role == 'hrd' || role == 'superadmin';
}
