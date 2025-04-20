import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Widget _buildExportButton() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Text(
            'Cetak Excel',
            style: TextStyle(
              color: Color(0xFF133E87),
              fontWeight: FontWeight.w500,
              fontSize: 14,
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