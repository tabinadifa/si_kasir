import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:open_file/open_file.dart'; 
import 'package:path_provider/path_provider.dart';
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
  try {
    setState(() {
      isExporting = true;
    });

    // Buat dokumen Excel
    final excel = Excel.createExcel();
    final sheet = excel['Produk Terjual $selectedYear'];

    // Hapus Sheet1 default
    if (excel.sheets.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Header
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

    // Style untuk header
    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF133E87'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = headerStyle;
    }

    // Grupkan produk berdasarkan kategori
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

    // Tambahkan data produk
    for (var category in groupedProducts.keys) {
      // Header kategori
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('Kategori: $category')
        ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FFEEEEEE'),
        );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: headers.length - 1, rowIndex: rowIndex),
      );
      rowIndex++;

      // Inisialisasi total kategori
      int totalProduk = 0;
      int totalTerjual = 0;
      int totalTersisa = 0;

      for (var product in groupedProducts[category]!) {
        final stok = (product['stok'] ?? 0) as int;
        final terjual = (product['terjual'] ?? 0) as int;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(productNumber.toString());

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(product['nama']?.toString() ?? '');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(product['kategori']?.toString() ?? '');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue('Rp${NumberFormat('#,###').format(product['harga'] ?? 0)}');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue((stok + terjual).toString());

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(terjual.toString());

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(stok.toString());

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = TextCellValue(product['status']?.toString() ?? '');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .value = TextCellValue((product['isBestSellerInCategory'] == true ? 'Ya' : 'Tidak'));

        // Update total
        totalProduk += stok + terjual;
        totalTerjual += terjual;
        totalTersisa += stok;

        rowIndex++;
        productNumber++;
      }

      // Baris total per kategori
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
        ..value = TextCellValue('Total')
        ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FFCCCCCC'),
        );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
        ..value = TextCellValue(totalProduk.toString())
        ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FFCCCCCC'),
        );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
        ..value = TextCellValue(totalTerjual.toString())
        ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FFCCCCCC'),
        );

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
        ..value = TextCellValue(totalTersisa.toString())
        ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FFCCCCCC'),
        );

      rowIndex++;
      rowIndex++;
    }

    // Set lebar kolom
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15.0);
    }
    sheet.setColumnWidth(1, 25.0);

    await _saveToLocalStorage(excel);

  } catch (e) {
    print('Error exporting to Excel: $e');
    _showErrorDialog('Gagal mengekspor data: ${e.toString()}');
  } finally {
    setState(() {
      isExporting = false;
    });
  }
}


 Future<void> _saveToLocalStorage(Excel excel) async {
    try {
      // Hanya untuk Android, langsung gunakan external storage directory
      Directory? directory = await getExternalStorageDirectory();
      String newPath = '';
      
      // Split path untuk mendapatkan direktori Download
      List<String> paths = directory!.path.split('/');
      for (int x = 1; x < paths.length; x++) {
        String folder = paths[x];
        if (folder != 'Android') {
          newPath += '/$folder';
        } else {
          break;
        }
      }
      newPath = '$newPath/Download';
      directory = Directory(newPath);

      // Buat direktori jika belum ada
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName = 'Produk_Terjual_${selectedYear}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception('Gagal mengencode Excel');
      }

      final file = File(filePath);
      await file.writeAsBytes(excelBytes, flush: true);
      
      _showSuccessDialog('Laporan berhasil disimpan', filePath);
      
    } on MissingPluginException catch (e) {
      _showErrorDialog('Plugin tidak tersedia: ${e.message}\nPastikan aplikasi sudah di-rebuild');
    } catch (e) {
      _showErrorDialog('Gagal menyimpan file: ${e.toString()}');
    }
  }

void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 50,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Terjadi Kesalahan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 void _showSuccessDialog(String message, String filePath) {
    final fileName = filePath.split('/').last;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Color(0xFF133E87).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF133E87),
                  size: 50,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Ekspor Berhasil!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133E87),
                ),
              ),
              SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF133E87)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Tutup',
                        style: TextStyle(
                          color: Color(0xFF133E87),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final result = await OpenFile.open(filePath);
                          if (result.type != ResultType.done) {
                            _showErrorDialog(
                                'Gagal membuka file: ${result.message}');
                          }
                        } catch (e) {
                          _showErrorDialog(
                              'Gagal membuka file: ${e.toString()}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF133E87),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Buka File',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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