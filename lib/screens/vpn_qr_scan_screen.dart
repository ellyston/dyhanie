import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';

class VpnQrScanScreen extends StatefulWidget {
  const VpnQrScanScreen({super.key});

  @override
  State<VpnQrScanScreen> createState() => _VpnQrScanScreenState();
}

class _VpnQrScanScreenState extends State<VpnQrScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.pop(context, raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('vpn_qr_title'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                L.t('vpn_qr_hint'),
                textAlign: TextAlign.center,
                style: FontService.style(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}