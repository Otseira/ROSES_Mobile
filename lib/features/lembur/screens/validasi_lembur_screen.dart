import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class ValidasiLemburScreen extends ConsumerStatefulWidget {
  const ValidasiLemburScreen({super.key});
  @override
  ConsumerState<ValidasiLemburScreen> createState() =>
      _ValidasiLemburScreenState();
}

class _ValidasiLemburScreenState extends ConsumerState<ValidasiLemburScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String _status = 'Pending'; // tab: Pending | Disetujui | Ditolak

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
      final res = await api.get('/lembur/validasi', query: {'status': _status});
      if (res['success'] == true) {
        setState(() => _items = (res['data'] as List?) ?? []);
      } else {
        setState(() => _error = res['message']?.toString());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _proses(int id, String action) async {
    String? catatan;
    if (action == 'Ditolak') {
      final c = await _askCatatan();
      if (c == null) return; // batal
      catatan = c;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.post(
        '/lembur/validasi/$id',
        data: {'action': action, if (catatan != null) 'catatan': catatan},
      );
      if (res['success'] == true) {
        _fetch(); // refresh list
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString();
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<String?> _askCatatan() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alasan Penolakan'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Wajib diisi...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              Navigator.pop(ctx, t.isEmpty ? 'Ditolak oleh atasan.' : t);
            },
            child: const Text('Tolak'),
          ),
        ],
      ),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Validasi Lembur / On-Call')),
      body: Column(
        children: [
          // Tab status
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    child: Text(
                      'Tidak ada data "$_status".',
                      style: const TextStyle(color: AppColors.textHint),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final it = _items[i] as Map;
                        final id = it['id'] as int;
                        final isPending = _status == 'Pending';
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
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      (it['pegawai_nama']?.toString() ?? '?')
                                          .substring(0, 1),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it['pegawai_nama']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (it['jenis_lembur'] == 'On-Call'
                                                  ? AppColors.error
                                                  : AppColors.info)
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      it['jenis_lembur']?.toString() ?? '-',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: it['jenis_lembur'] == 'On-Call'
                                            ? AppColors.error
                                            : AppColors.info,
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
                              // Foto bukti
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
                                  if (it['lat_masuk'] != null ||
                                      it['lat_keluar'] != null) ...[
                                    const SizedBox(width: 8),
                                    ActionChip(
                                      avatar: const Icon(Icons.map, size: 16),
                                      label: const Text(
                                        'Peta',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () => _openMap(
                                        (it['lat_masuk'] ?? it['lat_keluar'])
                                            ?.toDouble(),
                                        (it['lng_masuk'] ?? it['lng_keluar'])
                                            ?.toDouble(),
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
                                Row(
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
                                          style: TextStyle(
                                            color: AppColors.error,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _proses(id, 'Disetujui'),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Setujui'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
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
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
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
