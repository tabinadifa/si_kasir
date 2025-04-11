import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProdukTerjualScreen extends StatefulWidget {
  @override
  _ProdukTerjualScreenState createState() => _ProdukTerjualScreenState();
}

class _ProdukTerjualScreenState extends State<ProdukTerjualScreen> {
  int selectedYear = DateTime.now().year;
  final int endYear = DateTime.now().year;
  final int startYear = DateTime.now().year - 5;

  // Firebase related variables
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? userEmail;
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

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

    for (var doc in produkQuery.docs) {
      final produkData = doc.data();
      final produkId = doc.id;

      final transaksiQuery = await _firestore
          .collection('transaksi')
          .where('produkId', isEqualTo: produkId)
          .where('email', isEqualTo: userEmail)
          .where('tahun', isEqualTo: selectedYear)
          .get();

      int totalTerjual = 0;
      for (var transaksi in transaksiQuery.docs) {
        try {
          totalTerjual += (transaksi.data()['quantity'] as num).toInt();
        } catch (e) {
          print('Error on transaction ${transaksi.id}: $e');
        }
      }

      tempProducts.add({
        'id': produkId,
        'nama': produkData['nama'] ?? 'No Name',
        'stok': (produkData['stok'] as num).toInt(),
        'harga': (produkData['harga'] as num).toInt(),
        'status': produkData['status'] ?? 'Aktif',
        'terjual': totalTerjual,
      });
    }

    setState(() {
      products = tempProducts;
      isLoading = false;
    });

  } catch (e) {
    print('Error fetching products: $e');
    setState(() => isLoading = false);
  }
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
                Expanded(
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                        child: _buildProductCard(context, products[index]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
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
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, Map<String, dynamic> product) {
    final screenWidth = MediaQuery.of(context).size.width;
    // ignore: unused_local_variable
    final isSmallScreen = screenWidth < 360;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  product['nama'],
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (product['isBestSeller'])
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200], 
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Terlaris',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _buildInfoRow(
            context,
            Icons.calendar_month_outlined,
            'Periode: Januari $selectedYear',
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          _buildInfoRow(
            context,
            Icons.attach_money,
            'Harga: Rp${NumberFormat().format(product['harga'] ?? 0)}',
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          _buildInfoRow(
            context,
            Icons.category_outlined,
            'Kategori: ${product['kategori']}',
          ),
          if (product['isBestSeller']) ...[
            SizedBox(height: isSmallScreen ? 8 : 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                color: Color(0xFF133E87).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF133E87),
                    size: isSmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Paling laris di kategori ${product['kategori']}',
                      style: TextStyle(
                        color: Color(0xFF133E87),
                        fontSize: isSmallScreen ? 12 : 13,
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