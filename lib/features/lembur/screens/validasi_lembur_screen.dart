import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class ValidasiLemburScreen extends ConsumerStatefulWidget {
  const ValidasiLemburScreen({super.key});
  @override
  ConsumerState<ValidasiLemburScreen> createState() =>
      _ValidasiLemburScreenState();
}

class _ValidasiLemburScreenState extends ConsumerState<ValidasiLemburScreen> {
  // 0 = Lembur & On-Call (Ekstensi Shift / On-Call)
  // 1 = Ambil Jam (Pengambilan Saldo Jam)
  int _activeMenu = 0;

  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String _status = 'Pending'; // tab status: Pending | Disetujui | Ditolak
  int? _selectedUnitId; // null = semua unit yang dikelola

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      dynamic res;

      final queryParams = <String, dynamic>{
        'status': _status,
        if (_selectedUnitId != null) 'unit_id': _selectedUnitId,
      };

      if (_activeMenu == 0) {
        // Validasi Lembur & On-Call
        res = await api.get('/lembur/validasi', query: queryParams);
      } else {
        // Validasi Pengambilan Saldo Jam
        res = await api.get('/lembur/validasi-pengambilan', query: queryParams);
      }

      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _items = (res['data'] as List?) ?? []);
      } else {
        setState(() => _error = res['message']?.toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', '').trim());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _proses(int id, String action) async {
    String? catatan;
    if (action == 'Ditolak') {
      final c = await _askCatatan();
      if (c == null) return; // batal
      catatan = c;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      dynamic res;

      if (_activeMenu == 1) {
        // Proses validasi pengambilan saldo jam
        res = await api.post(
          '/lembur/validasi-pengambilan/$id',
          data: {'action': action, if (catatan != null) 'catatan': catatan},
        );
      } else {
        // Proses validasi lembur / on-call
        res = await api.post(
          '/lembur/validasi/$id',
          data: {'action': action, if (catatan != null) 'catatan': catatan},
        );
      }

      if (!mounted) return;
      if (res['success'] == true) {
        _fetch(); // refresh list
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '').trim();
        });
      }
    }
  }

  Future<String?> _askCatatan() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AlasanPenolakanDialog(),
    );
  }

  String _fmt(String? t) {
    if (t == null || t.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }

  void _openMap({dynamic lat, dynamic lng, String? mapUrl}) {
    if (mapUrl != null && mapUrl.isNotEmpty) {
      launchUrl(
        Uri.parse(mapUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if (lat == null || lng == null) return;
    final latNum = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
    final lngNum = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
    if (latNum == null || lngNum == null) return;
    launchUrl(
      Uri.parse('https://www.google.com/maps?q=$latNum,$lngNum'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storedUser = ref.watch(authStateProvider).value;
    final freshUser = ref.watch(freshProfileProvider).value;
    final user = freshUser ?? storedUser;
    final hasMultipleUnits = user != null && user.managesUnits.length > 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Persetujuan & Validasi',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh',
            onPressed: _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          // ===================================================================
          // 1. SEGMENTED SELECTOR: LEMBUR & ON-CALL VS AMBIL JAM (IDENTIK SIRO)
          // ===================================================================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_activeMenu == 0) return;
                        setState(() => _activeMenu = 0);
                        _fetch();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeMenu == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeMenu == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          'Lembur & On-Call',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeMenu == 0
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_activeMenu == 1) return;
                        setState(() => _activeMenu = 1);
                        _fetch();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeMenu == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeMenu == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          'Ambil Jam',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeMenu == 1
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===================================================================
          // 2. FILTER STATUS CHIP: PENDING | DISETUJUI | DITOLAK
          // ===================================================================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                for (final s in ['Pending', 'Disetujui', 'Ditolak'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        selected: _status == s,
                        selectedColor: const Color(0xFFECFDF5),
                        backgroundColor: const Color(0xFFF8FAFC),
                        labelStyle: TextStyle(
                          color: _status == s ? const Color(0xFF047857) : const Color(0xFF64748B),
                          fontWeight: _status == s ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _status == s ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _status = s);
                          _fetch();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ===================================================================
          // 3. FILTER UNIT (JIKA MANAJER MULTI-UNIT)
          // ===================================================================
          if (hasMultipleUnits) ...[
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Semua Unit', style: TextStyle(fontSize: 11)),
                      selected: _selectedUnitId == null,
                      selectedColor: const Color(0xFFECFDF5),
                      backgroundColor: const Color(0xFFF8FAFC),
                      labelStyle: TextStyle(
                        color: _selectedUnitId == null ? const Color(0xFF047857) : const Color(0xFF64748B),
                        fontWeight: _selectedUnitId == null ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _selectedUnitId == null ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (_) {
                        if (_selectedUnitId == null) return;
                        setState(() => _selectedUnitId = null);
                        _fetch();
                      },
                    ),
                    const SizedBox(width: 6),
                    for (final u in user.managesUnits) ...[
                      ChoiceChip(
                        label: Text(u.namaUnit, style: const TextStyle(fontSize: 11)),
                        selected: _selectedUnitId == u.id,
                        selectedColor: const Color(0xFFECFDF5),
                        backgroundColor: const Color(0xFFF8FAFC),
                        labelStyle: TextStyle(
                          color: _selectedUnitId == u.id ? const Color(0xFF047857) : const Color(0xFF64748B),
                          fontWeight: _selectedUnitId == u.id ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedUnitId == u.id ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (_) {
                          if (_selectedUnitId == u.id) return;
                          setState(() => _selectedUnitId = u.id);
                          _fetch();
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],

          // ===================================================================
          // 4. DAFTAR ITEM VALIDASI (IDENTIK DENGAN KARTU SIRO)
          // ===================================================================
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 44,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _activeMenu == 1
                                        ? 'Tidak ada permohonan ambil jam "$_status".'
                                        : 'Semua permohonan lembur "$_status" telah diproses.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _fetch,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final it = _items[i] as Map;
                                final id = it['id'] as int;
                                final isPending = _status == 'Pending';

                                if (_activeMenu == 1) {
                                  return _buildAmbilJamCard(it: it, id: id, isPending: isPending);
                                }
                                return _buildLemburCard(it: it, id: id, isPending: isPending);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ================= KARTU LEMBUR & ON-CALL =================
  Widget _buildLemburCard({
    required Map it,
    required int id,
    required bool isPending,
  }) {
    final status = it['status_validasi'] ?? _status;
    final namaPegawai = it['pegawai_nama'] ?? it['nama_pegawai'] ?? '-';
    final unitKerja = it['unit_nama'] ?? it['unit_kerja'] ?? '';
    final jenisLembur = it['jenis_lembur'] ?? 'Lembur';
    final alasan = it['keterangan'] ?? it['alasan_lembur'] ?? 'Tanpa keterangan';
    final tgl = it['tanggal_lembur'] ?? it['tanggal'] ?? '-';
    final mulai = it['waktu_mulai'] ?? '-';
    final selesai = it['waktu_selesai'] ?? '-';
    final durasi = it['durasi_detail'] ?? it['durasi_teks'] ?? '${it['durasi_menit'] ?? 0} Menit';
    final jarak = it['jarak_teks'] ?? (it['jarak_meter'] != null ? '${it['jarak_meter']} meter dari RS' : null);

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusFg = const Color(0xFFB45309);
    if (status == 'Disetujui') {
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF047857);
    } else if (status == 'Ditolak') {
      statusBg = const Color(0xFFFFE4E6);
      statusFg = const Color(0xFFBE123C);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama Pegawai & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaPegawai.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$unitKerja • $jenisLembur',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Durasi Detail Badge (Berapa menit lalu dalam kurung berapa jamnya)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF047857)),
                const SizedBox(width: 6),
                Text(
                  durasi.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Box Keterangan / Alasan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALASAN / TUGAS LEMBUR:',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alasan.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tanggal & Jam
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tgl.toString(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              Text(
                '$mulai - $selesai',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          // Info Peta & Jarak dari RS
          if (jarak != null || it['lat_masuk'] != null || it['latitude_masuk'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 15, color: Color(0xFFE11D48)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            jarak?.toString() ?? 'Lokasi GPS Tercatat',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _openMap(
                      mapUrl: it['map_url']?.toString(),
                      lat: it['lat_masuk'] ?? it['latitude_masuk'] ?? it['lat_keluar'] ?? it['latitude_keluar'],
                      lng: it['lng_masuk'] ?? it['longitude_masuk'] ?? it['lng_keluar'] ?? it['longitude_keluar'],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'Buka Peta',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Foto bukti jika ada
          if (it['foto_masuk_url'] != null || it['foto_keluar_url'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (it['foto_masuk_url'] != null)
                  _thumb(it['foto_masuk_url'].toString(), 'Bukti Masuk'),
                if (it['foto_keluar_url'] != null) ...[
                  const SizedBox(width: 8),
                  _thumb(it['foto_keluar_url'].toString(), 'Bukti Keluar'),
                ],
              ],
            ),
          ],

          // Tombol Aksi Verifikasi (Hanya di Tab Pending)
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _proses(id, 'Ditolak'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF1F2),
                      foregroundColor: const Color(0xFFBE123C),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tolak',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _proses(id, 'Disetujui'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Setujui',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ================= KARTU PENGAMBILAN SALDO JAM =================
  Widget _buildAmbilJamCard({
    required Map it,
    required int id,
    required bool isPending,
  }) {
    final status = it['status_validasi'] ?? _status;
    final namaPegawai = it['pegawai_nama'] ?? it['nama_pegawai'] ?? '-';
    final durasi = it['durasi_detail'] ?? it['durasi_teks'] ?? '${it["durasi_menit"]} Menit';
    final alasan = it['alasan'] ?? it['keterangan'] ?? 'Tanpa keterangan';
    final tglRencana = it['tanggal_rencana'] ?? it['tanggal'] ?? '-';

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusFg = const Color(0xFFB45309);
    if (status == 'Disetujui') {
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF047857);
    } else if (status == 'Ditolak') {
      statusBg = const Color(0xFFFFE4E6);
      statusFg = const Color(0xFFBE123C);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaPegawai.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Durasi: $durasi',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              alasan.toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF334155),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Rencana Tanggal: $tglRencana',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),

          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _proses(id, 'Ditolak'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF1F2),
                      foregroundColor: const Color(0xFFBE123C),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tolak',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _proses(id, 'Disetujui'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Setujui',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumb(String url, String label) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }
}

class _AlasanPenolakanDialog extends StatefulWidget {
  const _AlasanPenolakanDialog();
  @override
  State<_AlasanPenolakanDialog> createState() => _AlasanPenolakanDialogState();
}

class _AlasanPenolakanDialogState extends State<_AlasanPenolakanDialog> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Alasan Penolakan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(hintText: 'Tuliskan catatan alasan penolakan…'),
        maxLines: 2,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, _ctrl.text.trim());
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBE123C)),
          child: const Text('Tolak Permohonan'),
        ),
      ],
    );
  }
}
