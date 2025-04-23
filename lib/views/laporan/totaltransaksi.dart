import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class TotalTransaksiScreen extends StatefulWidget {
  @override
  _TotalTransaksiScreenState createState() => _TotalTransaksiScreenState();
}

class _TotalTransaksiScreenState extends State<TotalTransaksiScreen> {
  int selectedYear = DateTime.now().year;
  final int endYear = DateTime.now().year;
  final int startYear = DateTime.now().year - 5;

  double totalLunas = 0;
  double totalHutang = 0;
  double totalPendapatan = 0;
  double totalPengeluaran = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userEmail;
  bool isLoading = true;
  bool isExporting = false;

  // Simpan data transaksi untuk ekspor
  List<Map<String, dynamic>> transaksiData = [];
  List<Map<String, dynamic>> pengeluaranData = [];

  @override
  void initState() {
    super.initState();
    _getUserEmail();
  }

  Future<void> _getUserEmail() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      // Reset data lists
      transaksiData = [];
      pengeluaranData = [];
    });
    
    if (userEmail != null) {
      await _calculateTransaksi();
      await _calculatePengeluaran();
      
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _calculateTransaksi() async {
    print("Mengambil data transaksi untuk tahun $selectedYear");

    double lunas = 0;
    double hutang = 0;

    DateTime startDate = DateTime(selectedYear, 1, 1);
    DateTime endDate = DateTime(selectedYear, 12, 31, 23, 59, 59);
    
    Timestamp startTimestamp = Timestamp.fromDate(startDate);
    Timestamp endTimestamp = Timestamp.fromDate(endDate);

    try {
      QuerySnapshot transaksiSnapshot = await _firestore
          .collection('transaksi')
          .where('email', isEqualTo: userEmail)
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();

      for (var doc in transaksiSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Add to transaksiData for export
        transaksiData.add({
          'id': doc.id,
          'tanggal': data['timestamp'] != null 
              ? DateFormat('dd/MM/yyyy').format((data['timestamp'] as Timestamp).toDate()) 
              : '-',
          'pelanggan': data['customerName'] ?? '-',
          'total': data['totalAmount'] ?? 0,
          'status': data['status'] ?? '-',
        });

        if (data['status'] == 'Lunas') {
          lunas += (data['totalAmount'] ?? 0).toDouble();
        } else if (data['status'] == 'Belum Lunas') {
          hutang += (data['totalAmount'] ?? 0).toDouble();
        }
      }

      setState(() {
        totalLunas = lunas;
        totalHutang = hutang;
        // Total pendapatan diambil dari jumlah transaksi lunas dan hutang
        totalPendapatan = totalLunas + totalHutang;
      });
    } catch (e) {
      print("Error mengambil data transaksi: $e");
    }
  }

  Future<void> _calculatePengeluaran() async {
    double pengeluaran = 0;

    // Menghitung tanggal awal dan akhir dari tahun yang dipilih
    DateTime startDate = DateTime(selectedYear, 1, 1);
    DateTime endDate = DateTime(selectedYear, 12, 31, 23, 59, 59);
    
    Timestamp startTimestamp = Timestamp.fromDate(startDate);
    Timestamp endTimestamp = Timestamp.fromDate(endDate);

    try {
      // 1. Hitung pengeluaran dari produk (hargaBeli * stok)
      QuerySnapshot produkSnapshot = await _firestore
          .collection('produk')
          .where('email', isEqualTo: userEmail)
          .where('updatedAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('updatedAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      for (var doc in produkSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double hargaBeli = (data['hargaBeli'] ?? 0).toDouble();
        int stok = (data['stok'] ?? 0);
        
        pengeluaranData.add({
          'id': doc.id,
          'nama': data['nama'] ?? '-',
          'tanggal': data['updatedAt'] != null 
              ? DateFormat('dd/MM/yyyy').format((data['updatedAt'] as Timestamp).toDate()) 
              : '-',
          'hargaBeli': hargaBeli,
          'stok': stok,
          'total': hargaBeli * stok,
          'jenis': 'Produk',
        });
        
        pengeluaran += hargaBeli * stok;
      }

      // 2. Hitung pengeluaran dari array products dalam transaksi
      QuerySnapshot transaksiSnapshot = await _firestore
          .collection('transaksi')
          .where('email', isEqualTo: userEmail)
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();

      for (var doc in transaksiSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Periksa apakah ada field products dan itu adalah array
        if (data.containsKey('products') && data['products'] is List) {
          List<dynamic> products = data['products'];
          
          for (var product in products) {
            if (product is Map<String, dynamic>) {
              double hargaBeli = (product['hargaBeli'] ?? 0).toDouble();
              int quantity = (product['quantity'] ?? 0);
              
              pengeluaranData.add({
                'id': doc.id,
                'nama': product['nama'] ?? '-',
                'tanggal': data['timestamp'] != null 
                    ? DateFormat('dd/MM/yyyy').format((data['timestamp'] as Timestamp).toDate()) 
                    : '-',
                'hargaBeli': hargaBeli,
                'stok': quantity,
                'total': hargaBeli * quantity,
                'jenis': 'Transaksi',
              });
              
              pengeluaran += hargaBeli * quantity;
            }
          }
        }
      }

      setState(() {
        totalPengeluaran = pengeluaran;
      });
    } catch (e) {
      print("Error mengambil data pengeluaran: $e");
    }
  }

  // Fungsi untuk format uang
  String formatPrice(double price) {
    return 'Rp${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  // Fungsi untuk ekspor ke Excel
  Future<void> _exportToExcel() async {
    try {
      setState(() {
        isExporting = true;
      });
      
      // Membuat objek Excel
      final excel = Excel.createExcel();
      
      // Menghapus sheet default jika ada
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // ===== Sheet Ringkasan =====
      final sheetSummary = excel['Ringkasan'];
      
      // Judul
      var titleCell = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = TextCellValue('LAPORAN KEUANGAN TAHUN $selectedYear');
      titleCell.cellStyle = CellStyle(bold: true);
      
      // Header Ringkasan
      var headerCellKategori = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
      headerCellKategori.value = TextCellValue('Kategori');
      headerCellKategori.cellStyle = CellStyle(bold: true);
      
      var headerCellJumlah = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2));
      headerCellJumlah.value = TextCellValue('Jumlah');
      headerCellJumlah.cellStyle = CellStyle(bold: true);
      
      // Data Ringkasan
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('Transaksi Lunas');
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = DoubleCellValue(totalLunas);
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = TextCellValue('Transaksi Hutang');
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = DoubleCellValue(totalHutang);
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5)).value = TextCellValue('Total Pendapatan');
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value = DoubleCellValue(totalPendapatan);
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6)).value = TextCellValue('Total Pengeluaran');
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6)).value = DoubleCellValue(totalPengeluaran);
      
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 7)).value = TextCellValue('Laba Bersih');
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 7)).value = DoubleCellValue(totalPendapatan - totalPengeluaran);
      
      // Menyesuaikan lebar kolom
      sheetSummary.setColumnWidth(0, 20);
      sheetSummary.setColumnWidth(1, 15);

      // ===== Sheet Transaksi =====
      if (transaksiData.isNotEmpty) {
        final sheetTransaksi = excel['Transaksi'];
        
        // Header Transaksi
        final headers = ['No', 'ID Transaksi', 'Tanggal', 'Nama Pelanggan', 'Total', 'Status'];
        for (int i = 0; i < headers.length; i++) {
          var headerCell = sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          headerCell.value = TextCellValue(headers[i]);
          headerCell.cellStyle = CellStyle(bold: true);
        }
        
        // Data Transaksi
        for (int i = 0; i < transaksiData.length; i++) {
          final data = transaksiData[i];
          sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = IntCellValue(i + 1);
          sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(data['id']);
          sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(data['tanggal']);
          sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(data['pelanggan']);
          sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = DoubleCellValue(data['total']);
          sheetTransaksi.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value = TextCellValue(data['status']);
        }
        
        // Menyesuaikan lebar kolom
        sheetTransaksi.setColumnWidth(0, 5);
        sheetTransaksi.setColumnWidth(1, 15);
        sheetTransaksi.setColumnWidth(2, 12);
        sheetTransaksi.setColumnWidth(3, 25);
        sheetTransaksi.setColumnWidth(4, 15);
        sheetTransaksi.setColumnWidth(5, 12);
      }
      
      // ===== Sheet Pengeluaran =====
      if (pengeluaranData.isNotEmpty) {
        final sheetPengeluaran = excel['Pengeluaran'];
        
        // Header Pengeluaran
        final headers = ['No', 'ID', 'Nama Item', 'Tanggal', 'Harga Beli', 'Jumlah', 'Total', 'Jenis'];
        for (int i = 0; i < headers.length; i++) {
          var headerCell = sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          headerCell.value = TextCellValue(headers[i]);
          headerCell.cellStyle = CellStyle(bold: true);
        }
        
        // Data Pengeluaran
        for (int i = 0; i < pengeluaranData.length; i++) {
          final data = pengeluaranData[i];
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = IntCellValue(i + 1);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(data['id']);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(data['nama']);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(data['tanggal']);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = DoubleCellValue(data['hargaBeli']);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value = IntCellValue(data['stok']);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1)).value = DoubleCellValue(data['total']);
          sheetPengeluaran.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i + 1)).value = TextCellValue(data['jenis']);
        }
        
        // Menyesuaikan lebar kolom
        sheetPengeluaran.setColumnWidth(0, 5);
        sheetPengeluaran.setColumnWidth(1, 15);
        sheetPengeluaran.setColumnWidth(2, 25);
        sheetPengeluaran.setColumnWidth(3, 12);
        sheetPengeluaran.setColumnWidth(4, 15);
        sheetPengeluaran.setColumnWidth(5, 10);
        sheetPengeluaran.setColumnWidth(6, 15);
        sheetPengeluaran.setColumnWidth(7, 12);
      }
      
      // Save and share the file
      await _saveAndShareExcel(excel);
      
      setState(() {
        isExporting = false;
      });
    } catch (e) {
      print("Error exporting to Excel: $e");
      _showErrorDialog("Terjadi kesalahan saat mengekspor data ke Excel: $e");
      setState(() {
        isExporting = false;
      });
    }
  }

  Future<void> _saveAndShareExcel(Excel excel) async {
    try {
      // Nama file dengan format: Laporan_Keuangan_TAHUN_DDMMYYYY_HHMMSS.xlsx
      final now = DateTime.now();
      final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(now);
      final fileName = 'Laporan_Keuangan_${selectedYear}_$formattedDate.xlsx';
      
      // Get temporary directory
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String filePath = '$tempPath/$fileName';
      
      // Encode Excel file
      List<int>? excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception("Failed to encode Excel file");
      }
      
      // Write to file
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excelBytes);
      
      // Share file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Laporan Keuangan Tahun $selectedYear',
      );
      
    } catch (e) {
      print("Error saving Excel file: $e");
      _showErrorDialog("Terjadi kesalahan saat menyimpan file Excel: $e");
    }
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return GestureDetector(
      onTap: (isLoading || isExporting) ? null : _exportToExcel,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: (isLoading || isExporting) ? Colors.grey[300] : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: isExporting
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Color(0xFF133E87),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Cetak Excel',
                  style: TextStyle(
                    color: (isLoading || isExporting) ? Colors.grey[600] : Color(0xFF133E87),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Total Transaksi',
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
      body: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 10 : 12,
                horizontal: isSmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF133E87),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        'Tahun',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: selectedYear,
                    dropdownColor: const Color(0xFF133E87),
                    style: const TextStyle(color: Colors.white),
                    underline: Container(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: List.generate(
                      endYear - startYear + 1,
                      (index) {
                        int year = endYear - index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(
                            '$year',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedYear = value!;
                      });
                      // Reload data when year changes
                      _loadData();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 18 : 24),
            Expanded(
              child: isLoading 
                ? Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF133E87),
                    ),
                  )
                : GridView.count(
                    crossAxisCount: isSmallScreen ? 1 : 2,
                    crossAxisSpacing: isSmallScreen ? 12 : 16,
                    mainAxisSpacing: isSmallScreen ? 12 : 16,
                    childAspectRatio: isSmallScreen ? 1.2 : 1.1,
                    children: [
                      buildCard(context, 'Transaksi Lunas', formatPrice(totalLunas), Icons.check_circle_outline),
                      buildCard(context, 'Transaksi Hutang', formatPrice(totalHutang), Icons.cancel_outlined),
                      buildCard(context, 'Pendapatan', formatPrice(totalPendapatan), Icons.trending_up),
                      buildCard(context, 'Pengeluaran', formatPrice(totalPengeluaran), Icons.trending_down),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCard(BuildContext context, String title, String value, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF133E87).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFF133E87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF133E87),
                size: isSmallScreen ? 20 : 24,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF133E87),
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}