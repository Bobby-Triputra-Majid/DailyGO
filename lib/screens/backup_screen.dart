import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/asset_provider.dart';
import '../providers/finance_provider.dart';
import '../utils/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Pulihkan Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data hanya tersimpan di HP ini. Backup secara berkala supaya tidak hilang kalau aplikasi dihapus.',
                    style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Backup Data'),
              subtitle: const Text('Simpan semua catatan ke sebuah file'),
              trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _busy ? null : _export,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Pulihkan Data'),
              subtitle: const Text('Ganti data saat ini dengan file backup'),
              trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _busy ? null : _import,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = BackupService.exportToJson();
      final fileName = 'kasku_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: fileName);
      await SharePlus.instance.share(ShareParams(files: [file], text: 'Backup data KasKu'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final picked = result?.files.single;
    if (picked?.bytes == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data?'),
        content: const Text(
          'Semua kategori, transaksi, dan utang/piutang yang ada SEKARANG akan diganti dengan isi file ini. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Pulihkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final content = utf8.decode(picked!.bytes!);
      await BackupService.importFromJson(content);
      if (mounted) {
        context.read<FinanceProvider>().refresh();
        context.read<AssetProvider>().refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dipulihkan')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File backup tidak valid')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
