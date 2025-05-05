import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:si_kasir/views/transaksi/piutang/detail_data_piutang.dart';

class DataPiutangScreen extends StatefulWidget {
  @override
  _DataPiutangScreenState createState() => _DataPiutangScreenState();
}

class _DataPiutangScreenState extends State<DataPiutangScreen> {
  String selectedStatus = "Semua"; 
  late String selectedMonth;
  late int selectedYear;
  final int currentYear = DateTime.now().year;
  bool isExporting = false;
  List<Map<String, dynamic>> piutangData = [];
  final List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];
  final List<int> years = [];

  final Color primaryColor = Color(0xFF133E87);
  final Color accentColor = Color(0xFF133E87);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String userEmail;

  // Controller untuk search bar
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    selectedMonth = months[DateTime.now().month - 1];
    selectedYear = currentYear;
    for (int year = currentYear; year >= currentYear - 5; year--) {
      years.add(year);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email ?? '';
      });
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  Stream<QuerySnapshot> _getPiutangStream() {
    // Convert selected month to numeric value (1-12)
    int monthIndex = months.indexOf(selectedMonth) + 1;

    // Create date range for selected month and year
    DateTime startDate = DateTime(selectedYear, monthIndex, 1);
    DateTime endDate = monthIndex < 12
        ? DateTime(selectedYear, monthIndex + 1, 1)
        : DateTime(selectedYear + 1, 1, 1);

    // Query dasar untuk mengambil data piutang berdasarkan email, paymentMethod, dan periode waktu
    Query query = _firestore
        .collection('transaksi')
        .where('email', isEqualTo: userEmail)
        .where('paymentMethod', isEqualTo: 'piutang')
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .where('timestamp', isLessThan: endDate)
        .orderBy('timestamp', descending: true);

    // Tambahkan filter status jika tidak memilih "Semua"
    if (selectedStatus != "Semua") {
      query = query.where('status', isEqualTo: selectedStatus);
    }

    return query.snapshots();
  }

  Future<void> _refreshData() async {
    setState(() {
      // Refresh dilakukan otomatis karena menggunakan StreamBuilder
    });
  }

  Future<void> _exportToExcel() async {
  try {
    setState(() {
      isExporting = true;
    });

    // Get the current filtered data
    final querySnapshot = await _getPiutangStream().first;
    piutangData = querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'customerName': data['customerName'] ?? 'Tidak Diketahui',
        'totalAmount': data['totalAmount'] ?? 0,
        'timestamp': _formatTimestamp(data['timestamp'] as Timestamp),
        'status': data['status'] ?? 'Belum Lunas',
      };
    }).toList();

    final excel = Excel.createExcel();
    
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Sheet Piutang
    final sheetPiutang = excel['Piutang'];
    
    // Style for headers
    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF133E87'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),   
      horizontalAlign: HorizontalAlign.Center,
    );

    // Add title with date range
    sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('LAPORAN PIUTANG ${selectedMonth} ${selectedYear}')
      ..cellStyle = headerStyle;
    
    sheetPiutang.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                       CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0));

    // Add headers
    final headers = ['No', 'ID Transaksi', 'Nama Pelanggan', 'Tanggal', 'Jumlah Dibayar', 'Sisa Hutang', 'Total', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2))
        ..value = TextCellValue(headers[i])
        ..cellStyle = headerStyle;
    }
    
    // Add data rows
    for (int i = 0; i < piutangData.length; i++) {
      final data = piutangData[i];
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 3)).value = IntCellValue(i + 1);
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 3)).value = TextCellValue(data['id']?.toString() ?? '-');
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 3)).value = TextCellValue(data['customerName']?.toString() ?? '-');
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 3)).value = TextCellValue(data['timestamp']?.toString() ?? '-');
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 3)).value = DoubleCellValue(_toDouble(data['initialPayment']));
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i + 3)).value = DoubleCellValue(_toDouble(data['remainingDebt']));
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 3)).value = DoubleCellValue(_toDouble(data['totalAmount']));
      sheetPiutang.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 3)).value = TextCellValue(data['status']?.toString() ?? '-');
    }
    
    // Set column widths
    sheetPiutang.setColumnWidth(0, 5);  
    sheetPiutang.setColumnWidth(1, 20); 
    sheetPiutang.setColumnWidth(2, 30); 
    sheetPiutang.setColumnWidth(3, 15);
    sheetPiutang.setColumnWidth(6, 15); 
    sheetPiutang.setColumnWidth(7, 15); 
    sheetPiutang.setColumnWidth(4, 15); 
    sheetPiutang.setColumnWidth(5, 15); 

    // Add summary sheet
    final sheetSummary = excel['Ringkasan'];
    
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('RINGKASAN PIUTANG ${selectedMonth} ${selectedYear}')
      ..cellStyle = headerStyle;
    
    sheetSummary.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                       CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));

    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = TextCellValue('Kategori')
      ..cellStyle = headerStyle;
    
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
      ..value = TextCellValue('Jumlah')
      ..cellStyle = headerStyle;
    
    // Calculate totals
    double totalPiutang = piutangData.fold(0, (sum, item) => sum + _toDouble(item['totalAmount']));
    double totalLunas = piutangData
        .where((item) => item['status'] == 'Lunas')
        .fold(0, (sum, item) => sum + _toDouble(item['totalAmount']));
    double totalBelumLunas = piutangData
        .where((item) => item['status'] == 'Belum Lunas')
        .fold(0, (sum, item) => sum + _toDouble(item['totalAmount']));

    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('Total Piutang');
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = DoubleCellValue(totalPiutang);
    
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = TextCellValue('Piutang Lunas');
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = DoubleCellValue(totalLunas);
    
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5)).value = TextCellValue('Piutang Belum Lunas');
    sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value = DoubleCellValue(totalBelumLunas);
    
    sheetSummary.setColumnWidth(0, 20);
    sheetSummary.setColumnWidth(1, 15);

    await _saveToLocalStorage(excel);
    
    setState(() {
      isExporting = false;
    });
  } catch (e) {
    print("Error exporting to Excel: $e");
    _showErrorDialog("Terjadi kesalahan saat mengekspor data ke Excel: ${e.toString()}");
    setState(() {
      isExporting = false;
    });
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value.toString()) ?? 0.0;
}

Future<void> _requestPermission() async {
  if (await Permission.manageExternalStorage.isGranted) {
    return;
  }
  
  var status = await Permission.manageExternalStorage.request();
  if (!status.isGranted) {
    throw Exception('Permission denied');
  }
}

Future<void> _saveToLocalStorage(Excel excel) async {
  try {
    await _requestPermission();
    Directory? directory = await getExternalStorageDirectory();
    String newPath = '';
    
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

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = 'Laporan_Piutang_${selectedMonth}_${selectedYear}.xlsx';
    final filePath = '${directory.path}/$fileName';
    
    final excelBytes = excel.encode();
    if (excelBytes == null) {
      throw Exception('Gagal mengencode Excel');
    }

    final file = File(filePath);
    await file.writeAsBytes(excelBytes, flush: true);
    
    _showSuccessDialog('Laporan piutang berhasil disimpan', filePath);
    
  } on MissingPluginException catch (e) {
    _showErrorDialog('Plugin tidak tersedia: ${e.message}\nPastikan aplikasi sudah di-rebuild');
  } catch (e) {
    _showErrorDialog('Gagal menyimpan file: ${e.toString()}');
  }
}

void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Terjadi Kesalahan', style: TextStyle(color: Colors.red)),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Data Piutang',
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
      body: Column(
        children: [
          // Search Bar baru di bawah AppBar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Cari di sini',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: primaryColor,
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Colors.grey.shade600, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Filter Row: Status, Bulan, dan Tahun - IMPROVED LAYOUT
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Status Dropdown - Menggunakan Expanded dengan flex yang sama
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        isExpanded:
                            true, // Memastikan dropdown mengisi seluruh container
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: primaryColor,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedStatus = newValue!;
                          });
                        },
                        items: ["Semua", "Belum Lunas", "Lunas"]
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8), // Jarak antara dropdown

                // Bulan Dropdown
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        isExpanded:
                            true, // Memastikan dropdown mengisi seluruh container
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: primaryColor,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedMonth = newValue!;
                          });
                        },
                        items: months.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8), // Jarak antara dropdown bulan dan tahun

                // Tahun Dropdown
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedYear.toString(),
                        isExpanded:
                            true, // Memastikan dropdown mengisi seluruh container
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: primaryColor,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedYear = int.parse(newValue!);
                          });
                        },
                        items: years.map((int year) {
                          return DropdownMenuItem<String>(
                            value: year.toString(),
                            child: Text(year.toString(),
                                style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Data Piutang
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: StreamBuilder<QuerySnapshot>(
                stream: _getPiutangStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                        child:
                            Text('Tidak ada data piutang pada periode ini.'));
                  }

                  final allTransactions = snapshot.data!.docs;

                  // Filter berdasarkan pencarian jika ada query
                  final transactions = _searchQuery.isEmpty
                      ? allTransactions
                      : allTransactions.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final customerName = (data['customerName'] ?? '')
                              .toString()
                              .toLowerCase();
                          return customerName.contains(_searchQuery);
                        }).toList();

                  if (transactions.isEmpty) {
                    return Center(
                        child: Text(
                            'Tidak ada hasil yang sesuai dengan pencarian.'));
                  }

                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final data = transaction.data() as Map<String, dynamic>;
                      final customerName =
                          data['customerName'] ?? 'Tidak Diketahui';
                      final totalAmount = data['totalAmount'] ?? 0;
                      final timestamp = data['timestamp'] as Timestamp;
                      final formattedDate = _formatTimestamp(timestamp);
                      final status = data['status'] ?? 'Belum Lunas';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.grey.shade400, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(15),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailPiutangScreen(
                                      transactionId: transaction.id,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customerName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.black87),
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 16,
                                                  color: Color(0xFF133E87)),
                                              SizedBox(width: 8),
                                              Text(formattedDate,
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 14)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Rp${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(totalAmount)}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}