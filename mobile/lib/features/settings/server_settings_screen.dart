import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_text_field.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _hostController = TextEditingController();
  bool _testing = false;
  bool _saving = false;
  String? _testMessage;
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    _hostController.text = ApiConfig.activeHost;
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = 'IP server wajib diisi';
      });
      return;
    }

    setState(() {
      _testing = true;
      _testMessage = null;
      _testOk = null;
    });

    try {
      final url = ApiConfig.healthUrlForHost(host);
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        await ApiConfig.setHost(host);
        if (!mounted) return;
        setState(() {
          _testOk = true;
          _testMessage = 'Terhubung & disimpan: ${ApiConfig.baseUrl}';
        });
      } else {
        setState(() {
          _testOk = false;
          _testMessage = 'Server merespons ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = 'Gagal: $e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ApiConfig.setHost(host).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server disimpan: ${ApiConfig.baseUrl}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetDefault() async {
    await ApiConfig.clearHostOverride();
    if (!mounted) return;
    setState(() => _hostController.text = ApiConfig.activeHost);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kembali ke IP default compile')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pengaturan Server')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
              Text(
                'Aktif sekarang: ${ApiConfig.baseUrl}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'HP dan Mac harus satu jaringan.\n'
                  'Hotspot HP: connect Mac ke WiFi hotspot, lalu cek IP Mac di terminal:\n'
                  'ipconfig getifaddr en0\n'
                  'Masukkan IP tersebut di bawah (bukan IP HP).',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _hostController,
                label: 'IP Mac / server',
                hint: '10.29.98.92',
                prefixIcon: Icons.dns_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                'Port: ${ApiConfig.port} (backend uvicorn)',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _testMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _testOk == true
                        ? Colors.green.shade700
                        : AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: 'Tes koneksi',
                onPressed: _testing ? null : _testConnection,
                isLoading: _testing,
                variant: AppButtonVariant.secondary,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Simpan',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resetDefault,
                child: const Text('Reset ke default'),
              ),
          ],
        ),
      ),
    );
  }
}
