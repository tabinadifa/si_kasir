import 'package:flutter/material.dart';

class ProdukTerjualScreen extends StatefulWidget {
  @override
  _ProdukTerjualScreenState createState() => _ProdukTerjualScreenState();
}

class _ProdukTerjualScreenState extends State<ProdukTerjualScreen> {
  int selectedYear = DateTime.now().year;
  final int endYear = DateTime.now().year;
  final int startYear = DateTime.now().year - 5;

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
              _buildProductCard(context),
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

  Widget _buildProductCard(BuildContext context) {
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
              Text(
                'Kopi Renceng',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF133E87).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Aktif',
                  style: TextStyle(
                    color: Color(0xFF133E87),
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          _buildStats(context),
          SizedBox(height: isSmallScreen ? 12 : 16),
          _buildProductDetail(context),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // ignore: unused_local_variable
    final isSmallScreen = screenWidth < 360;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.inventory_2_outlined,
            value: '3',
            label: 'Total\nProduk',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.shopping_cart_outlined,
            value: '2',
            label: 'Terjual',
          ),
        ),
        Expanded(
          child: _buildStatItem(
            context,
            icon: Icons.store_outlined,
            value: '1',
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

  Widget _buildProductDetail(BuildContext context) {
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
              Text(
                'Kopi Goodday',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            'Periode: Januari 2024',
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          _buildInfoRow(
            context,
            Icons.attach_money,
            'Harga: Rp12.000',
          ),
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
                    'Paling laris di kategori kopi renceng',
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
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: isSmallScreen ? 12 : 14,
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