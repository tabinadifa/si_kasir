import 'package:flutter/material.dart';
import 'package:si_kasir/views/transaksi/nontunai/nontunai.dart';
import 'package:si_kasir/views/transaksi/piutang/piutang.dart';
import 'package:si_kasir/views/transaksi/tunai/tunai.dart';

class RiwayatTransaksiScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF133E87),
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12.0 : 20.0,
            vertical: isSmallScreen ? 16.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTransactionOption(
                context: context,
                icon: Icons.attach_money,
                title: 'Transaksi Tunai',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TransaksiTunaiScreen()),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildTransactionOption(
                context: context,
                icon: Icons.credit_card,
                title: 'Transaksi Non-Tunai',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TransaksiNonTunaiScreen()),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildTransactionOption(
                context: context,
                icon: Icons.trending_up,
                title: 'Kelola Piutang',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DataPiutangScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth >= 600;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        elevation: 3.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                    decoration: BoxDecoration(
                      color: Color(0xFFE9EEF5),
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                    ),
                    child: Icon(
                      icon,
                      color: Color(0xFF133E87),
                      size: isSmallScreen
                          ? 24
                          : isLargeScreen
                              ? 30
                              : 28,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8.0 : 16.0),
                  Center(
                    // Menambahkan Center untuk membuat judul di tengah
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen
                            ? 16
                            : isLargeScreen
                                ? 20
                                : 18,
                      ),
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF133E87),
                size: isSmallScreen ? 20 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}