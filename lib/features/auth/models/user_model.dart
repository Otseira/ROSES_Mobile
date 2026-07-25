class UserModel {
  final int id;
  final String nik;
  final String username;
  final String nama;
  final String? email;
  final String? nomorWhatsapp;
  final String? unitKerja;
  final String role;

  UserModel({
    required this.id,
    required this.nik,
    required this.username,
    required this.nama,
    this.email,
    this.nomorWhatsapp,
    this.unitKerja,
    required this.role,
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
  };

  bool get isSuperadmin => role == 'superadmin';
  bool get canAbsen => role != 'superadmin';
  bool get canValidasi =>
      role == 'kepala_unit' || role == 'hrd' || role == 'superadmin';
}
