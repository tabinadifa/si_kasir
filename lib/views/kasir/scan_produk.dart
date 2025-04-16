import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanProdukScreen extends StatefulWidget {
  final Function(Product)? onProductScanned;
  
  const ScanProdukScreen({super.key, this.onProductScanned});

  @override
  State<ScanProdukScreen> createState() => _ScanProdukScreenState();
}

class _ScanProdukScreenState extends State<ScanProdukScreen> {
  MobileScannerController controller = MobileScannerController();
  String scanResult = '';
  bool isScanning = true;
  bool isLoading = false;
  Product? scannedProduct;

  // Define custom colors
  final Color primaryBlue = const Color(0xFF133E87);
  final Color pureWhite = Colors.white;
  final Color pureBlack = Colors.black;
  final Color errorRed = const Color(0xFFD32F2F);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> checkProduct(String barcode) async {
    setState(() {
      isLoading = true;
    });

    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('produk')
          .where('email', isEqualTo: user.email)
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          scannedProduct = null;
          scanResult = 'Produk tidak tersedia';
          isScanning = false;
          isLoading = false;
        });
      } else {
        final doc = querySnapshot.docs.first;
        final product = Product.fromFirestore(doc);
        
        setState(() {
          scannedProduct = Product.fromScannedProduct(product); // Menggunakan factory constructor
          scanResult = product.name;
          isScanning = false;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        scanResult = 'Error: ${e.toString()}';
        isScanning = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Scanner View
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!isScanning) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  checkProduct(barcode.rawValue!);
                }
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
                  pureBlack.withOpacity(0.5),
                  Colors.transparent,
                  Colors.transparent,
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
                  isScanning 
                    ? 'Arahkan ke Barcode Produk' 
                    : isLoading 
                      ? 'Memeriksa produk...'
                      : scanResult,
                  style: TextStyle(
                    color: isScanning || isLoading 
                      ? pureWhite 
                      : scannedProduct != null 
                        ? pureWhite 
                        : errorRed,
                    fontSize: isScanning ? 16 : 20,
                    fontWeight: isScanning ? FontWeight.normal : FontWeight.bold,
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
          if (scanResult.isNotEmpty && !isScanning && !isLoading)
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
                        scannedProduct != null ? 'Produk Terdeteksi' : 'Produk Tidak Ditemukan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: scannedProduct != null ? primaryBlue : errorRed,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scanResult,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scannedProduct != null ? primaryBlue : errorRed,
                        ),
                      ),
                      if (scannedProduct != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Rp${formatPrice(scannedProduct!.price)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  scanResult = '';
                                  isScanning = true;
                                  scannedProduct = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                          if (scannedProduct != null)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (scannedProduct != null && widget.onProductScanned != null) {
                                    widget.onProductScanned!(scannedProduct!);
                                    // Tampilkan pesan sukses
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${scannedProduct!.name} ditambahkan ke keranjang'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                    // Reset state
                                    setState(() {
                                      scanResult = '';
                                      isScanning = true;
                                      scannedProduct = null;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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

String formatPrice(double price) {
  return price.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String productId; // Diubah dari product_id untuk konsistensi
  final double buyPrice;
  final String imageUrl;
  final String barcode;
  final int stock;
  final String category;
  int quantity;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.barcode,
    required this.price,
    required this.buyPrice,
    required this.imageUrl,
    required this.productId,
    required this.stock,
    required this.category,
    this.quantity = 0, // Default 0, akan di-set ke 1 saat discan
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      productId: data['productId'] ?? '',
      name: data['namaProduk'] ?? '',
      description: data['deskripsi'] ?? '',
      price: (data['hargaJual'] ?? 0).toDouble(),
      buyPrice: (data['hargaBeli'] ?? 0).toDouble(),
      barcode: data['barcode'] ?? '',
      imageUrl: data['gambarUrl'] ?? '',
      stock: data['stok'] ?? 0,
      category: data['kategori'] ?? '',
    );
  }

  factory Product.fromScannedProduct(Product original) {
    return Product(
      id: original.id,
      name: original.name,
      description: original.description,
      barcode: original.barcode,
      price: original.price,
      buyPrice: original.buyPrice,
      imageUrl: original.imageUrl,
      productId: original.productId,
      stock: original.stock,
      category: original.category,
      quantity: 1, // Set quantity ke 1 untuk produk yang discan
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'buyPrice': buyPrice,
      'imageUrl': imageUrl,
      'barcode': barcode,
      'stock': stock,
      'category': category,
      'quantity': quantity,
    };
  }
}