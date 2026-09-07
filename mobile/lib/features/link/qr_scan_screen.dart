import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/qr_helper.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.title});

  final String title;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _processing = false;

  Future<void> _handleScan(String? raw) async {
    if (_processing || raw == null) return;
    final userId = QrHelper.parseUserId(raw);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code tidak valid')),
        );
      }
      return;
    }

    setState(() => _processing = true);
    if (mounted) Navigator.pop(context, userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                _handleScan(barcode.rawValue);
                break;
              }
            },
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.black.withValues(alpha: 0.6),
              child: const Text(
                'Arahkan kamera ke QR code',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
