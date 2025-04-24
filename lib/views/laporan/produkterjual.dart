import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border; 
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'dart:io';

class ProdukTerjualScreen extends StatefulWidget {
  @override
  _ProdukTerjualScreenState createState() => _ProdukTerjualScreenState();
}

class _ProdukTerjualScreenState extends State<ProdukTerjualScreen> {
  int selectedYear = DateTime.now().year;
  final int endYear = DateTime.now().year;
  final int startYear = DateTime.now().year - 5;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? userEmail;
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });
      await _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    if (userEmail == null) return;

    try {
      final produkQuery = await _firestore
          .collection('produk')
          .where('email', isEqualTo: userEmail)
          .get();

      List<Map<String, dynamic>> tempProducts = [];
      Map<String, int> productSales = {};

      final transaksiQuery = await _firestore
          .collection('transaksi')
          .where('email', isEqualTo: userEmail)
          .get();

      for (var transaksi in transaksiQuery.docs) {
        final transaksiData = transaksi.data();
        final timestamp = transaksiData['timestamp'] as Timestamp?;
        
        if (timestamp != null && timestamp.toDate().year == selectedYear) {
          final products = transaksiData['products'] as List<dynamic>?;
          
          if (products != null) {
            for (var product in products) {
              final productId = product['id']?.toString();
              final quantity = (product['quantity'] ?? 0) as int;
              
              if (productId != null) {
                productSales.update(
                  productId,
                  (value) => value + quantity,
                  ifAbsent: () => quantity
                );
              }
            }
          }
        }
      }

      for (var doc in produkQuery.docs) {
        final produkData = doc.data();
        final produkId = doc.id;
        final totalTerjual = productSales[produkId] ?? 0;

        tempProducts.add({
          'id': produkId,
          'nama': produkData['namaProduk'] ?? 'No Name',
          'stok': (produkData['stok'] ?? 0).toInt(),
          'harga': (produkData['hargaJual'] ?? 0).toInt(),
          'status': produkData['status'] ?? 'Aktif',
          'terjual': totalTerjual,
          'kategori': produkData['kategori'] ?? 'Umum',
          'namaProduk': produkData['namaProduk'] ?? 'No Name',
        });
      }

      // Kelompokkan produk berdasarkan kategori
      Map<String, List<Map<String, dynamic>>> productsByCategory = {};
      for (var product in tempProducts) {
        final category = product['kategori'] ?? 'Umum';
        if (!productsByCategory.containsKey(category)) {
          productsByCategory[category] = [];
        }
        productsByCategory[category]!.add(product);
      }

      // Tentukan best seller per kategori
      for (var category in productsByCategory.keys) {
        final categoryProducts = productsByCategory[category]!;
        if (categoryProducts.isNotEmpty) {
          // Urutkan berdasarkan penjualan tertinggi
          categoryProducts.sort((a, b) => (b['terjual'] ?? 0).compareTo(a['terjual'] ?? 0));
          final maxSold = categoryProducts.first['terjual'] ?? 0;
          
          // Tandai sebagai best seller jika penjualan > 0
          if (maxSold > 0) {
            for (var product in categoryProducts) {
              product['isBestSellerInCategory'] = product['terjual'] == maxSold;
            }
          }
        }
      }

      // Gabungkan kembali semua produk
      tempProducts = productsByCategory.values.expand((x) => x).toList();

      setState(() {
        products = tempProducts;
        isLoading = false;
      });

    } catch (e) {
      print('Error fetching products: $e');
      setState(() => isLoading = false);
    }
  }

  // Function to export data to Excel
  Future<void> _exportToExcel() async {
    if (products.isEmpty) {
      _showSnackBar('Tidak ada data untuk diekspor');
      return;
    }

    try {
      setState(() {
        isExporting = true;
      });

      // Request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          _showSnackBar('Izin penyimpanan diperlukan untuk menyimpan file');
          setState(() {
            isExporting = false;
          });
          return;
        }
      }

      // Create Excel document
      final excel = Excel.createExcel();
      final sheet = excel['Produk Terjual $selectedYear'];

      // Add headers
      List<String> headers = [
        'No',
        'Nama Produk',
        'Kategori',
        'Harga',
        'Total Produk',
        'Terjual',
        'Tersisa',
        'Status',
        'Best Seller'
      ];

      // Style for headers
      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('FF133E87'),
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),   
        horizontalAlign: HorizontalAlign.Center,
      );

      // Add headers to sheet
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = headers[i] as CellValue?
          ..cellStyle = headerStyle;
      }

      // Group products by category
      Map<String, List<Map<String, dynamic>>> groupedProducts = {};
      for (var product in products) {
        final category = product['kategori'] ?? 'Umum';
        if (!groupedProducts.containsKey(category)) {
          groupedProducts[category] = [];
        }
        groupedProducts[category]!.add(product);
      }

      int rowIndex = 1;
      int productNumber = 1;

      // Add category headers and products
      for (var category in groupedProducts.keys) {
        // Add category header
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          ..value = 'Kategori: $category' as CellValue?
          ..cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('FFEEEEEE'),
          );
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex), 
                   CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: rowIndex));
        rowIndex++;

        // Add products for this category
        for (var product in groupedProducts[category]!) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = productNumber as CellValue?;
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = product['nama'];
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = product['kategori'];
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = 'Rp${NumberFormat('#,###').format(product['harga'] ?? 0)}' as CellValue?;
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = (product['stok'] ?? 0) + (product['terjual'] ?? 0);
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = product['terjual'] ?? 0;
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = product['stok'] ?? 0;
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = product['status'];
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
            .value = (product['isBestSellerInCategory'] == true ? 'Ya' : 'Tidak') as CellValue?;

          rowIndex++;
          productNumber++;
        }

        // Add empty row after each category
        rowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15.0);
      }
        sheet.setColumnWidth(1, 25.0); 

      // Save file
      final fileName = 'Produk_Terjual_${selectedYear}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx';
      
      Directory? directory;
      if (Platform.isAndroid) {
        // For Android, save to Downloads folder
        directory = Directory('/storage/emulated/0/Download');
        // Create directory if it doesn't exist
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // For iOS, save to Documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // For other platforms
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      // Save the excel file
      final excelData = excel.encode();
      if (excelData != null) {
        await file.writeAsBytes(excelData);
        
        _showSnackBar('File berhasil disimpan di: $filePath');
        
        // For iOS where files are saved to app's documents directory,
        // you may want to use share plugin to let the user access the file
        if (Platform.isIOS) {
          // ShareExtend.share(filePath, "file");
          // Note: You'd need to add the share_extend package for this
        }
      } else {
        throw Exception('Failed to encode Excel data');
      }

    } catch (e) {
      print('Error exporting to Excel: $e');
      _showSnackBar('Gagal mengekspor data: ${e.toString()}');
    } finally {
      setState(() {
        isExporting = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildExportButton() {
    return GestureDetector(
      onTap: isExporting ? null : _exportToExcel,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: isExporting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF133E87)),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_download,
                        color: Color(0xFF133E87),
                        size: 18,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Cetak Excel',
                        style: TextStyle(
                          color: Color(0xFF133E87),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Produk Terjual',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildExportButton(),
          ),
        ],
        backgroundColor: Color(0xFF133E87),
        elevation: 0,
      ),
      backgroundColor: Colors.white, 
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          child: Column(
            children: [
              _buildYearDropdown(),
              SizedBox(height: isSmallScreen ? 8 : 12),
              if (isLoading)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF133E87)),
                    ),
                  ),
                )
              else if (products.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'Tidak ada produk ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tahun $selectedYear',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildProductList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // Kelompokkan produk berdasarkan kategori
    Map<String, List<Map<String, dynamic>>> groupedProducts = {};
    for (var product in products) {
      final category = product['kategori'] ?? 'Umum';
      if (!groupedProducts.containsKey(category)) {
        groupedProducts[category] = [];
      }
      groupedProducts[category]!.add(product);
    }

    return Expanded(
      child: ListView(
        children: [
          for (var category in groupedProducts.keys)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133E87),
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${groupedProducts[category]!.length} Produk',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ...groupedProducts[category]!.map((product) => Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                  child: _buildProductCard(context, product),
                )).toList(),
                SizedBox(height: 8),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF133E87),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Tahun',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          DropdownButton<int>(
            value: selectedYear,
            dropdownColor: Color(0xFF133E87),
            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: SizedBox(),
            style: TextStyle(color: Colors.white, fontSize: 16),
            onChanged: (int? newValue) {
              setState(() {
                selectedYear = newValue!;
                isLoading = true;
              });
              _fetchProducts();
            },
            items: List.generate(
              endYear - startYear + 1,
              (index) => DropdownMenuItem(
                value: startYear + index,
                child: Text((startYear + index).toString(),
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              Flexible(
                child: Text(
                  product['nama'],
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (product['status'] == 'Aktif'
                          ? Color(0xFF133E87)
                          : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  product['status'],
                  style: TextStyle(
                    color: product['status'] == 'Aktif'
                        ? Color(0xFF133E87)
                        : Colors.red,
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildStats(context, product),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildProductDetail(context, product),
          if (product['isBestSellerInCategory'] == true) ...[
            SizedBox(height: isSmallScreen ? 8 : 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: isSmallScreen ? 16 : 18),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Best Seller Kategori ${product['kategori']}',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, Map<String, dynamic> product) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.inventory_2_outlined,
            value: '${(product['stok'] ?? 0) + (product['terjual'] ?? 0)}',
            label: 'Total\nProduk',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.shopping_cart_outlined,
            value: '${product['terjual'] ?? 0}',
            label: 'Terjual',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.store_outlined,
            value: '${product['stok'] ?? 0}',
            label: 'Tersisa',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 6),
      padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 8 : 12, horizontal: isSmallScreen ? 4 : 8),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Color(0xFF133E87), size: isSmallScreen ? 20 : 24),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetail(BuildContext context, Map<String, dynamic> product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildInfoRow(
            context,
            Icons.calendar_month_outlined,
            'Periode: Januari - Desember $selectedYear',
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          _buildInfoRow(
            context,
            Icons.attach_money,
            'Harga: Rp${NumberFormat('#,###').format(product['harga'] ?? 0)}',
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          _buildInfoRow(
            context,
            Icons.category_outlined,
            'Kategori: ${product['kategori'] ?? 'Umum'}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Row(
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 14 : 16,
          color: Colors.grey[600],
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: isSmallScreen ? 12 : 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primaryColor: Color(0xFF133E87),
      scaffoldBackgroundColor: Colors.white,
    ),
    home: ProdukTerjualScreen(),
  ));
}