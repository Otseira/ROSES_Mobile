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
  // 3 Menu Validasi:
  // 0 = Validasi Lembur (Ekstensi Shift)
  // 1 = Validasi On-Call
  // 2 = Validasi Pengambilan Waktu Lembur
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
        // Validasi Lembur (Ekstensi Shift)
        queryParams['jenis_lembur'] = 'Ekstensi Shift';
        res = await api.get('/lembur/validasi', query: queryParams);
      } else if (_activeMenu == 1) {
        // Validasi On-Call
        queryParams['jenis_lembur'] = 'On-Call';
        res = await api.get('/lembur/validasi', query: queryParams);
      } else {
        // Validasi Pengambilan Waktu Lembur (Ganti Jam Kerja)
        res = await api.get('/lembur/validasi-pengambilan', query: queryParams);
      }

      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _items = (res['data'] as List?) ?? []);
      } else {
        setState(() => _error = res['message']?.toString());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

      if (_activeMenu == 2) {
        // Proses validasi pengambilan waktu lembur
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
          _error = e.toString();
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
      return DateFormat(
        'dd MMM yyyy, HH:mm',
        'id_ID',
      ).format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }

  void _openMap(double? lat, double? lng) {
    if (lat == null || lng == null) return;
    launchUrl(
      Uri.parse('https://www.google.com/maps?q=$lat,$lng'),
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
        title: const Text('Validasi Lembur & On-Call'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ================= 3 MENU UTAMA VALIDASI =================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                _buildMenuTab(
                  index: 0,
                  icon: Icons.schedule,
                  label: 'Validasi Lembur',
                ),
                const SizedBox(width: 8),
                _buildMenuTab(
                  index: 1,
                  icon: Icons.phone_in_talk,
                  label: 'Validasi On-Call',
                ),
                const SizedBox(width: 8),
                _buildMenuTab(
                  index: 2,
                  icon: Icons.swap_horiz,
                  label: 'Pengambilan Waktu',
                ),
              ],
            ),
          ),

          // ================= FILTER STATUS (Pending / Disetujui / Ditolak) =================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final s in ['Pending', 'Disetujui', 'Ditolak'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        selected: _status == s,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _status == s
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: _status == s
                              ? FontWeight.bold
                              : FontWeight.normal,
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
          const Divider(height: 1),

          // ================= FILTER UNIT (Untuk Manajer Multi-Unit) =================
          if (hasMultipleUnits) ...[
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Semua Unit', style: TextStyle(fontSize: 11)),
                      selected: _selectedUnitId == null,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _selectedUnitId == null
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: _selectedUnitId == null
                            ? FontWeight.bold
                            : FontWeight.normal,
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
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedUnitId == u.id
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: _selectedUnitId == u.id
                              ? FontWeight.bold
                              : FontWeight.normal,
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
            const Divider(height: 1),
          ],

          // ================= DAFTAR ITEM VALIDASI =================
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _activeMenu == 2
                                      ? Icons.hourglass_empty
                                      : Icons.check_circle_outline,
                                  size: 48,
                                  color: AppColors.textHint.withOpacity(0.5),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tidak ada data "$_status".',
                                  style: const TextStyle(
                                      color: AppColors.textHint),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 90),
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) {
                                final it = _items[i] as Map;
                                final id = it['id'] as int;
                                final isPending = _status == 'Pending';

                                if (_activeMenu == 2) {
                                  return _buildPengambilanWaktuCard(
                                    it: it,
                                    id: id,
                                    isPending: isPending,
                                  );
                                }

                                return _buildLemburCard(
                                  it: it,
                                  id: id,
                                  isPending: isPending,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ================= TAB MENU SELECTOR =================
  Widget _buildMenuTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeMenu == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_activeMenu == index) return;
          setState(() => _activeMenu = index);
          _fetch();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= KARTU LEMBUR / ON-CALL =================
  Widget _buildLemburCard({
    required Map it,
    required int id,
    required bool isPending,
  }) {
    final isEkstensi = it['jenis_lembur'] != 'On-Call';
    final badgeColor = isEkstensi ? AppColors.primary : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  (it['pegawai_nama']?.toString() ?? '?').substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it['pegawai_nama']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${it['pegawai_nik']} • ${it['unit_nama']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  it['jenis_lembur']?.toString() ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.schedule,
            'Mulai',
            _fmt(it['waktu_mulai']?.toString()),
          ),
          _infoRow(
            Icons.flag,
            'Selesai',
            _fmt(it['waktu_selesai']?.toString()),
          ),
          _infoRow(
            Icons.timer,
            'Durasi',
            '${it['total_jam'] ?? '-'} jam',
          ),
          _infoRow(
            Icons.notes,
            'Keterangan',
            it['keterangan']?.toString() ?? '-',
          ),
          const SizedBox(height: 10),

          // Foto bukti & Peta
          Row(
            children: [
              if (it['foto_masuk_url'] != null)
                _thumb(
                  it['foto_masuk_url'].toString(),
                  'Masuk',
                ),
              if (it['foto_keluar_url'] != null) ...[
                const SizedBox(width: 8),
                _thumb(
                  it['foto_keluar_url'].toString(),
                  'Keluar',
                ),
              ],
              if (it['lat_masuk'] != null || it['lat_keluar'] != null) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.map, size: 16),
                  label: const Text('Peta', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openMap(
                    (it['lat_masuk'] ?? it['lat_keluar'])?.toDouble(),
                    (it['lng_masuk'] ?? it['lng_keluar'])?.toDouble(),
                  ),
                ),
              ],
            ],
          ),
          if (it['catatan_validasi'] != null) ...[
            const SizedBox(height: 10),
            Text(
              'Catatan: ${it['catatan_validasi']}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Tombol aksi (hanya di tab Pending)
          if (isPending) ...[
            const SizedBox(height: 14),
            _buildActionButtons(id),
          ],
        ],
      ),
    );
  }

  // ================= KARTU PENGAMBILAN WAKTU LEMBUR =================
  Widget _buildPengambilanWaktuCard({
    required Map it,
    required int id,
    required bool isPending,
  }) {
    final isMasukLambat = it['tipe_pengambilan'] == 'masuk_diperlambat';
    final badgeColor = isMasukLambat ? Colors.amber.shade700 : Colors.blue.shade700;
    final badgeBg = isMasukLambat ? Colors.amber.shade50 : Colors.blue.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple.shade50,
                child: Text(
                  (it['pegawai_nama']?.toString() ?? '?').substring(0, 1),
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it['pegawai_nama']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${it['pegawai_nik']} • ${it['unit_nama']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  isMasukLambat ? 'Masuk Lambat' : 'Pulang Cepat',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.event,
            'Tanggal Dinas',
            it['tanggal']?.toString() ?? '-',
          ),
          _infoRow(
            Icons.hourglass_top,
            'Durasi Ambil',
            it['durasi_teks']?.toString() ?? '${it['durasi_menit']} menit',
          ),
          _infoRow(
            Icons.category,
            'Jenis',
            it['tipe_label']?.toString() ?? (isMasukLambat ? 'Jam Masuk Diperlambat' : 'Jam Pulang Dipercepat'),
          ),
          _infoRow(
            Icons.notes,
            'Alasan',
            it['keterangan']?.toString() ?? '-',
          ),

          if (it['catatan_validasi'] != null) ...[
            const SizedBox(height: 10),
            Text(
              'Catatan Atasan: ${it['catatan_validasi']}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (it['divalidasi_pada_fmt'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Divalidasi: ${it['divalidasi_pada_fmt']}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ],

          // Tombol aksi (hanya di tab Pending)
          if (isPending) ...[
            const SizedBox(height: 14),
            _buildActionButtons(id),
          ],
        ],
      ),
    );
  }

  // ================= TOMBOL SETUJUI / TOLAK =================
  Widget _buildActionButtons(int id) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _proses(id, 'Ditolak'),
            icon: const Icon(
              Icons.close,
              color: AppColors.error,
              size: 18,
            ),
            label: const Text(
              'Tolak',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _proses(id, 'Disetujui'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Setujui'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData ic, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, size: 15, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String url, String label) {
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 56,
              height: 56,
              cacheWidth: 150,
              cacheHeight: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 30),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
        ],
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
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Alasan Penolakan'),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Tuliskan alasan penolakan...',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final t = _ctrl.text.trim();
            Navigator.pop(context, t.isEmpty ? 'Ditolak oleh atasan.' : t);
          },
          child: const Text('Tolak'),
        ),
      ],
    );
  }
}
