import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:mobile_scanner/mobile_scanner.dart';

class PindaiProdukScreen extends StatefulWidget {
  const PindaiProdukScreen({super.key});

  @override
  State<PindaiProdukScreen> createState() => _PindaiProdukScreenState();
}

class _PindaiProdukScreenState extends State<PindaiProdukScreen> {
  MobileScannerController controller = MobileScannerController();
  String scanResult = '';
  bool isScanning = true;

  // Define custom colors
  final Color primaryBlue = const Color(0xFF133E87);
  final Color pureWhite = Colors.white;
  final Color pureBlack = Colors.black;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Scanner View
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                setState(() {
                  scanResult = barcode.rawValue ?? 'Failed to scan';
                  isScanning = false;
                });
              }
            },
          ),

          // Overlay Design
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // ignore: deprecated_member_use
                  pureBlack.withOpacity(0.5),
                  Colors.transparent,
                  Colors.transparent,
                  // ignore: deprecated_member_use
                  pureBlack.withOpacity(0.5),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.darken,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),

          // Scan Area Indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: primaryBlue,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // Corner Decorations
                      ...List.generate(4, (index) {
                        return Positioned(
                          left: index < 2 ? -2 : null,
                          right: index >= 2 ? -2 : null,
                          top: index.isEven ? -2 : null,
                          bottom: index.isOdd ? -2 : null,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                left: index < 2
                                    ? BorderSide(color: primaryBlue, width: 2)
                                    : BorderSide.none,
                                top: index.isEven
                                    ? BorderSide(color: primaryBlue, width: 2)
                                    : BorderSide.none,
                                right: index >= 2
                                    ? BorderSide(color: primaryBlue, width: 2)
                                    : BorderSide.none,
                                bottom: index.isOdd
                                    ? BorderSide(color: primaryBlue, width: 2)
                                    : BorderSide.none,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isScanning ? 'Arahkan ke Barcode Produk' : scanResult,
                  style: TextStyle(
                    color: pureWhite,
                    fontSize: isScanning ? 16 : 20,
                    fontWeight:
                        isScanning ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Top Bar Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildControlButton(
                    icon: Icons.flashlight_on,
                    onPressed: () => controller.toggleTorch(),
                  ),
                  const SizedBox(width: 16),
                  _buildControlButton(
                    icon: Icons.cameraswitch,
                    onPressed: () => controller.switchCamera(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Result Card
          if (scanResult.isNotEmpty && !isScanning)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: pureWhite,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Produk Terdeteksi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: pureBlack,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scanResult,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  scanResult = '';
                                  isScanning = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: pureWhite,
                                foregroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: primaryBlue),
                                ),
                              ),
                              child: const Text('Scan Ulang'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, scanResult);
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: primaryBlue,
                                foregroundColor: pureWhite,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Tambah ke Keranjang'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: pureBlack.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: pureWhite, size: 28),
        onPressed: onPressed,
        splashRadius: 28,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
