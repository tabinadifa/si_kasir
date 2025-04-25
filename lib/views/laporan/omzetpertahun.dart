import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class OmzetPertahunScreen extends StatefulWidget {
  const OmzetPertahunScreen({super.key});

  @override
  State<OmzetPertahunScreen> createState() => _OmzetPertahunScreenState();
}

class _OmzetPertahunScreenState extends State<OmzetPertahunScreen> {
  // Data yang akan diisi dari Firestore
  Map<String, List<double>> yearlyData = {};
  Map<String, double> monthlyTotals = {};
  
  double totalOmzet = 0;
  String highestMonth = '';
  double highestMonthValue = 0;
  String lowestMonth = '';
  double lowestMonthValue = double.infinity;

  int selectedYear = DateTime.now().year;
  final int startYear = DateTime.now().year - 5;
  final int endYear = DateTime.now().year;
  int _touchedIndex = -1;
  bool isLoading = true;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    fetchOmzetData();
  }

  // Fungsi untuk mengambil dan menghitung data omzet dari Firestore
  Future<void> fetchOmzetData() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('Fetching data for years $startYear to $endYear');
      
      // Mengambil data transaksi
      final QuerySnapshot transactionSnapshot = await FirebaseFirestore.instance
          .collection('transaksi')
          .where('timestamp', isGreaterThanOrEqualTo: DateTime(startYear))
          .where('timestamp', isLessThan: DateTime(endYear + 1))
          .get();
      
      print('Found ${transactionSnapshot.docs.length} transactions');

      // Map untuk menyimpan ID produk dan jumlah terjual per bulan dan tahun
      Map<String, Map<String, Map<String, int>>> productQuantities = {};
      
      // Memproses data transaksi
      for (var doc in transactionSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Validasi field timestamp
          if (!data.containsKey('timestamp') || data['timestamp'] == null) {
            print('Document ${doc.id} has missing or null timestamp');
            continue;
          }
          
          final Timestamp timestamp = data['timestamp'] as Timestamp;
          final DateTime date = timestamp.toDate();
          final String year = date.year.toString();
          final String month = (date.month - 1).toString(); // 0-based untuk array
          
          // Validasi field products
          if (!data.containsKey('products') || data['products'] == null) {
            print('Document ${doc.id} has missing or null products field');
            continue;
          }
          
          if (data['products'] is! List) {
            print('Document ${doc.id} has products field that is not a List');
            continue;
          }
          
          if (!productQuantities.containsKey(year)) {
            productQuantities[year] = {};
          }
          
          if (!productQuantities[year]!.containsKey(month)) {
            productQuantities[year]![month] = {};
          }
          
          // Memproses array products dalam transaksi dengan handling null
          final List<dynamic> products = data['products'] as List<dynamic>;
          
          for (var product in products) {
            if (product == null || product is! Map<String, dynamic>) {
              print('Document ${doc.id} has an invalid product entry (null or not a Map)');
              continue;
            }
            
            // Validasi field productId dan quantity
            final String? productId = product['id']?.toString();
            final int quantity = product['quantity'] is int ? product['quantity'] as int : 0;
            
            if (productId == null || productId.isEmpty) {
              print('Document ${doc.id} has a product with null or empty productId');
              continue;
            }
            
            productQuantities[year]![month]![productId] = 
                (productQuantities[year]![month]![productId] ?? 0) + quantity;
          }
        } catch (e) {
          print('Error processing transaction document ${doc.id}: $e');
        }
      }
      
      // Mengambil data produk untuk harga
      final QuerySnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('produk')
          .get();
      
      print('Found ${productSnapshot.docs.length} products');
      
      Map<String, double> productPrices = {};
      for (var doc in productSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          if (!data.containsKey('hargaJual') || data['hargaJual'] == null) {
            print('Product ${doc.id} has missing or null hargaJual');
            continue;
          }
          
          // Konversi aman untuk hargaJual
          final dynamic rawPrice = data['hargaJual'];
          double price = 0.0;
          
          if (rawPrice is int) {
            price = rawPrice.toDouble();
          } else if (rawPrice is double) {
            price = rawPrice;
          } else if (rawPrice is String) {
            price = double.tryParse(rawPrice) ?? 0.0;
          }
          
          productPrices[doc.id] = price;
        } catch (e) {
          print('Error processing product document ${doc.id}: $e');
        }
      }
      
      // Menghitung omzet per bulan dan tahun
      yearlyData = {};
      monthlyTotals = {};
      
      for (var year in productQuantities.keys) {
        yearlyData[year] = List.generate(12, (index) => 0.0);
        
        for (var month in productQuantities[year]!.keys) {
          double monthTotal = 0;
          
          for (var productId in productQuantities[year]![month]!.keys) {
            final int quantity = productQuantities[year]![month]![productId]!;
            final double price = productPrices[productId] ?? 0.0;
            monthTotal += quantity * price;
          }
          
          int monthIndex = int.parse(month);
          yearlyData[year]![monthIndex] = monthTotal / 1000000; // Konversi ke juta
          
          String monthYearKey = '$month-$year';
          monthlyTotals[monthYearKey] = monthTotal;
        }
      }
      
      // Debug print untuk melihat data yang berhasil diproses
      yearlyData.forEach((year, data) {
        print('Year $year data: $data');
      });
      
      // Menghitung total omzet dan bulan tertinggi/terendah untuk tahun yang dipilih
      updateStatistics();
      
    } catch (e, stackTrace) {
      print('Error fetching data: $e');
      print('Stack trace: $stackTrace');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update statistik berdasarkan tahun yang dipilih
  void updateStatistics() {
    final String yearStr = selectedYear.toString();
    final List<double> selectedYearData = yearlyData[yearStr] ?? List.generate(12, (index) => 0.0);
    
    totalOmzet = 0;
    highestMonthValue = 0;
    lowestMonthValue = double.infinity;
    
    final allMonths = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    
    for (int i = 0; i < selectedYearData.length; i++) {
      double monthValue = selectedYearData[i];
      totalOmzet += monthValue;
      
      if (monthValue > highestMonthValue) {
        highestMonthValue = monthValue;
        highestMonth = allMonths[i];
      }
      
      if (monthValue < lowestMonthValue && monthValue > 0) {
        lowestMonthValue = monthValue;
        lowestMonth = allMonths[i];
      }
    }
    
    // Jika tidak ada data terendah yang valid, gunakan nilai default
    if (lowestMonthValue == double.infinity) {
      lowestMonthValue = 0;
      lowestMonth = 'Tidak ada data';
    }
  }

  // Fungsi untuk mengekspor data ke Excel
  Future<void> exportToExcel() async {
  setState(() {
    isExporting = true;
  });

  try {
    final excel = Excel.createExcel();
    final sheet = excel['Omzet Tahun $selectedYear'];

    final allMonths = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Bulan');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('Omzet (Rp)');

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('FF133E87'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).cellStyle = headerStyle;

    final List<double> currentYearData = yearlyData[selectedYear.toString()] ??
        List.generate(12, (index) => 0.0);

    for (int i = 0; i < allMonths.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(allMonths[i]);

      final double omzetValue = currentYearData[i] * 1000000;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = DoubleCellValue(omzetValue);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).cellStyle =
          CellStyle(numberFormat: NumFormat.standard_0);
    }

    final totalRow = allMonths.length + 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow)).value = TextCellValue('TOTAL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow)).cellStyle =
        CellStyle(bold: true);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow)).value =
        DoubleCellValue(totalOmzet * 1000000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow)).cellStyle =
        CellStyle(bold: true, numberFormat: NumFormat.standard_0);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow + 2)).value =
        TextCellValue('Bulan dengan omzet tertinggi');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow + 2)).value =
        TextCellValue(highestMonth);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow + 3)).value =
        TextCellValue('Omzet tertinggi');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow + 3)).value =
        DoubleCellValue(highestMonthValue * 1000000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow + 3)).cellStyle =
        CellStyle(numberFormat: NumFormat.standard_0);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow + 5)).value =
        TextCellValue('Bulan dengan omzet terendah');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow + 5)).value =
        TextCellValue(lowestMonth);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRow + 6)).value =
        TextCellValue('Omzet terendah');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow + 6)).value =
        DoubleCellValue(lowestMonthValue * 1000000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow + 6)).cellStyle =
        CellStyle(numberFormat: NumFormat.standard_0);

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);

    final fileName = 'Omzet_Tahun_$selectedYear.xlsx';

    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission denied');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final file = File(path);
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Data Omzet Tahun $selectedYear',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File Excel berhasil disimpan: $path')),
      );
    } else {
      throw Exception('Failed to generate Excel file');
    }
  } catch (e) {
    print('Error exporting to Excel: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: Gagal mengekspor data. ${e.toString()}')),
    );
  } finally {
    setState(() {
      isExporting = false;
    });
  }
}


  Future<void> insertSampleData() async {
    try {
      // Contoh produk
      await FirebaseFirestore.instance.collection('produk').doc('prod1').set({
        'nama': 'Produk 1',
        'hargaJual': 100000,
        'stok': 100
      });
      
      await FirebaseFirestore.instance.collection('produk').doc('prod2').set({
        'nama': 'Produk 2',
        'hargaJual': 150000,
        'stok': 75
      });
      
      // Contoh transaksi untuk beberapa bulan
      final currentYear = DateTime.now().year;
      
      // Transaksi bulan ini
      await FirebaseFirestore.instance.collection('transaksi').add({
        'timestamp': Timestamp.fromDate(DateTime(currentYear, DateTime.now().month, 15)),
        'products': [
          {'id': 'prod1', 'quantity': 3},
          {'id': 'prod2', 'quantity': 2}
        ],
        'total': 600000
      });
      
      // Transaksi bulan lalu
      await FirebaseFirestore.instance.collection('transaksi').add({
        'timestamp': Timestamp.fromDate(DateTime(currentYear, DateTime.now().month - 1, 15)),
        'products': [
          {'id': 'prod1', 'quantity': 5},
          {'id': 'prod2', 'quantity': 1}
        ],
        'total': 650000
      });
      
      // Tambahkan transaksi untuk beberapa bulan lain
      for (int i = 2; i < 6; i++) {
        await FirebaseFirestore.instance.collection('transaksi').add({
          'timestamp': Timestamp.fromDate(DateTime(currentYear, DateTime.now().month - i, 15)),
          'products': [
            {'id': 'prod1', 'quantity': i + 1},
            {'id': 'prod2', 'quantity': i}
          ],
          'total': (i + 1) * 100000 + i * 150000
        });
      }
      
      print('Sample data inserted successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data contoh berhasil ditambahkan!'))
      );
      
      // Ambil data setelah menambah data contoh
      fetchOmzetData();
      
    } catch (e) {
      print('Error inserting sample data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'))
      );
    }
  }

  Widget _buildBarChart(List<String> months, List<double> data) {
    // Temukan nilai maksimum untuk Y axis
    double maxY = data.isEmpty ? 10 : (data.reduce((a, b) => a > b ? a : b) * 1.2);
    maxY = maxY < 10 ? 10 : maxY;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1.7,
        child: Padding(
          padding: const EdgeInsets.only(top: 30.0, right: 30.0),
          child: BarChart(
            BarChartData(
              groupsSpace: 12,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${months[group.x]}\n${rod.toY.toStringAsFixed(1)}M',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  tooltipRoundedRadius: 8,
                  getTooltipColor: (group) => const Color(0xFF133E87),
                ),
                touchCallback: (event, response) {
                  if (response?.spot != null) {
                    setState(() {
                      _touchedIndex = response!.spot!.touchedBarGroupIndex;
                    });
                  }
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          months[value.toInt()],
                          style: TextStyle(
                            color: _touchedIndex == value.toInt()
                                ? const Color(0xFF133E87)
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 5,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}M',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[200],
                  strokeWidth: 1,
                ),
              ),
              barGroups: List.generate(months.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data[index],
                      gradient: _barsGradient,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: Colors.grey[100],
                      ),
                    ),
                  ],
                );
              }),
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: maxY,
                    color: Colors.grey[300],
                    strokeWidth: 1,
                    dashArray: [8],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient get _barsGradient => const LinearGradient(
        colors: [
          Color(0xFF133E87),
          Color(0xFF4B7DD1),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String month,
    required String amount,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: isSmallScreen ? 20 : 24),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            month,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF133E87),
            ),
          ),
          SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF133E87),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Tahun',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  )),
            ],
          ),
          DropdownButton<int>(
            value: selectedYear,
            dropdownColor: const Color(0xFF133E87),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedYear = newValue;
                  updateStatistics();
                });
              }
            },
            items: List.generate(
              endYear - startYear + 1,
              (index) => DropdownMenuItem<int>(
                value: startYear + index,
                child: Text(
                  (startYear + index).toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return GestureDetector(
      onTap: isExporting ? null : exportToExcel,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isExporting ? Colors.grey[300] : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: isExporting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF133E87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ekspor...',
                      style: TextStyle(
                        color: Color(0xFF133E87),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    const Text(
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

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(amount * 1000000); // Konversi kembali dari juta ke nilai asli
  }

  @override
  Widget build(BuildContext context) {
    final allMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    final List<double> currentYearData = yearlyData[selectedYear.toString()] ?? 
                                       List.generate(12, (index) => 0.0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Omzet Pertahun',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildExportButton(),
          ),
        ],
        backgroundColor: const Color(0xFF133E87),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF133E87)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Tambahkan indikator status data
                  if (yearlyData.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tidak ada data yang ditemukan',
                            style: TextStyle(
                              color: Colors.brown,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Periksa koleksi "transaksi" dan "produk" di Firestore Anda. Pastikan field timestamp, products, dan hargaJual sudah ada dan benar.',
                            style: TextStyle(color: Colors.brown),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: insertSampleData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[800],
                            ),
                            child: const Text('Tambah Data Contoh'),
                          ),
                        ],
                      ),
                    ),
                    
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildYearDropdown(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 400,
                        child: _buildBarChart(allMonths, currentYearData),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16, vertical: 16),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.bar_chart,
                                color: Color(0xFF133E87),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Total Omset',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            formatCurrency(totalOmzet),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF133E87),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 20 : 24),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return constraints.maxWidth < 600
                                  ? Column(
                                      children: [
                                        _buildStatCard(
                                          icon: Icons.trending_up,
                                          iconColor: Colors.blue[700]!,
                                          backgroundColor: Colors.blue[50]!,
                                          title: 'Bulan tertinggi',
                                          month: highestMonth,
                                          amount: formatCurrency(highestMonthValue),
                                          isSmallScreen: isSmallScreen,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildStatCard(
                                          icon: Icons.trending_down,
                                          iconColor: Colors.red[700]!,
                                          backgroundColor: Colors.red[50]!,
                                          title: 'Bulan terendah',
                                          month: lowestMonth,
                                          amount: formatCurrency(lowestMonthValue),
                                          isSmallScreen: isSmallScreen,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            icon: Icons.trending_up,
                                            iconColor: Colors.blue[700]!,
                                            backgroundColor: Colors.blue[50]!,
                                            title: 'Bulan tertinggi',
                                            month: highestMonth,
                                            amount: formatCurrency(highestMonthValue),
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildStatCard(
                                            icon: Icons.trending_down,
                                            iconColor: Colors.red[700]!,
                                            backgroundColor: Colors.red[50]!,
                                            title: 'Bulan terendah',
                                            month: lowestMonth,
                                            amount: formatCurrency(lowestMonthValue),
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                      ],
                                    );
                            },
                          ),
                          // Add export button inside the card
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: isExporting ? null : exportToExcel,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isExporting ? Colors.grey[300] : const Color(0xFF133E87),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: isExporting
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Mengekspor data...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Ekspor Data ke Excel',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: !isLoading && yearlyData.isEmpty
          ? FloatingActionButton(
              onPressed: insertSampleData,
              backgroundColor: const Color(0xFF133E87),
              child: const Icon(Icons.add_chart),
            )
          : null,
    );
  }
}

void main() => runApp(MaterialApp(
      theme: ThemeData(
        primaryColor: const Color(0xFF133E87),
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Inter',
      ),
      home: const OmzetPertahunScreen(),
      debugShowCheckedModeBanner: false,
    ));