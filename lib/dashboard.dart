import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:si_kasir/views/toko/read_toko.dart';
import 'package:si_kasir/views/kasir/daftar_produk.dart';
import 'package:si_kasir/views/laporan/laporan.dart';
import 'package:si_kasir/views/toko/create_toko.dart';
import 'package:si_kasir/views/laporan/totaltransaksi.dart';
import 'package:si_kasir/views/transaksi/transaksi.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String profileImageUrl = ''; 
  bool isLoadingProfile = true; 
  double totalSaldo = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfileData(); 
    _loadSaldoData();
  }

  String formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'id_ID', 
      symbol: 'Rp', 
      decimalDigits: 0, 
    );
    return format.format(amount);
  }

Future<void> _loadSaldoData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoadingProfile = false;
      });
      return;
    }

    final String emailUser = user.email!;
    final transaksiRef = FirebaseFirestore.instance.collection('transaksi');
    final querySnapshot = await transaksiRef.where('email', isEqualTo: emailUser).get();

    double total = 0.0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final paymentMethod = data['paymentMethod'] ?? 'tunai'; 
      final cashAmount = data['cashAmount'] ?? 0.0;
      final initialPayment = data['initialPayment'] ?? 0.0;
      final totalAmount = data['totalAmount'] ?? 0.0;

      if (paymentMethod == 'non-tunai') {
        total += totalAmount;
      } else if (paymentMethod == 'piutang') {
        total += initialPayment;
      } else {
        total += cashAmount;
      }
    }

    setState(() {
      totalSaldo = total;
    });
  } catch (e) {
    print('Error loading saldo data: $e');
  }
}
  Future<void> _loadProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoadingProfile = false;
        });
        return;
      }

      final String emailUser = user.email!;
      final tokoRef = FirebaseFirestore.instance.collection('toko');
      final querySnapshot = await tokoRef.where('email', isEqualTo: emailUser).get();

      if (querySnapshot.docs.isNotEmpty) {
        final profileData = querySnapshot.docs.first.data();
        setState(() {
          profileImageUrl = profileData['profile_image'] ?? ''; // Ambil URL gambar profil
          isLoadingProfile = false;
        });
      } else {
        setState(() {
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingProfile = false;
      });
      // ignore: avoid_print
      print('Error loading profile data: $e');
    }
  }

  Future<void> _launchHelpCenter() async {
    final Uri url = Uri.parse(
        'https://www.instagram.com/sikasir_app?utm_ source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka link')),
      );
    }
  }

  Future<void> _navigateToToko(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna belum login')),
        );
        return;
      }

      final String emailUser = user.email!;
      // ignore: avoid_print
      print('Email Pengguna: $emailUser');

      final tokoRef = FirebaseFirestore.instance.collection('toko');
      final querySnapshot =
          await tokoRef.where('email', isEqualTo: emailUser).get();

      final bool tokoAda = querySnapshot.docs.isNotEmpty;
      // ignore: avoid_print
      print('Dokumen ditemukan: $tokoAda');

      if (tokoAda) {
        // ignore: avoid_print
        print('Navigasi ke TokoScreen');
        Navigator.push(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (context) => TokoScreen()),
        );
      } else {
        // ignore: avoid_print
        print('Navigasi ke TambahTokoScreen');
        Navigator.push(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(builder: (context) => TambahTokoScreen()),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

Widget _buildHeader(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isSmallScreen = screenWidth < 360;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: screenWidth * 0.05,
      vertical: screenHeight * 0.02,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 0,
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () async => await _navigateToToko(context),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF133E87),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.grey.shade100,
                  radius: isSmallScreen ? 25 : 30,
                  child: isLoadingProfile
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF133E87)),
                        )
                      : profileImageUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                fit: BoxFit.cover,
                                width: isSmallScreen ? 50 : 60,
                                height: isSmallScreen ? 50 : 60,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    color: const Color(0xFF133E87),
                                    size: isSmallScreen ? 28 : 32,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: const Color(0xFF133E87),
                              size: isSmallScreen ? 28 : 32,
                            ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, Selamat Datang!',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF133E87),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  ElevatedButton(
                    onPressed: _launchHelpCenter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF133E87),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 20,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline, color: Colors.white),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          "Pusat Bantuan",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.02),
        Container(
          padding: EdgeInsets.all(screenWidth * 0.05),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF133E87), Color(0xFF1E56B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Saldo',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallScreen ? 12 : 14),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    formatCurrency(totalSaldo), // Format total saldo
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                      MaterialPageRoute(
                        builder: (context) => TotalTransaksiScreen(), 
                      ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 20,
                    vertical: isSmallScreen ? 8 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: const Color(0xFF133E87),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      'Dompet',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: const Color(0xFF133E87),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _buildMenuCard(IconData icon, String title,
      {required VoidCallback onTap, required BuildContext context}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: const Color(0xFF133E87).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: const Color(0xFF133E87),
                    size: isSmallScreen ? 28 : 32),
              ),
              SizedBox(height: screenWidth * 0.03),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF133E87),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Beranda',
          style: TextStyle(
            color: const Color(0xFF133E87),
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: screenWidth < 600 ? 2 : 3,
                    crossAxisSpacing: screenWidth * 0.04,
                    mainAxisSpacing: screenWidth * 0.04,
                    childAspectRatio: screenWidth < 360 ? 0.9 : 1.1,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMenuCard(
                        Icons.shopping_cart_outlined,
                        'Kasir',
                        context: context,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DaftarProdukScreen()),
                        ),
                      ),
                      _buildMenuCard(
                        Icons.receipt_long,
                        'Laporan',
                        context: context,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LaporanScreen()),
                        ),
                      ),
                      _buildMenuCard(
                        Icons.history,
                        'Riwayat',
                        context: context,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RiwayatTransaksiScreen()),
                        ),
                      ),
                      _buildMenuCard(
                        Icons.store_outlined,
                        'Toko',
                        context: context,
                        onTap: () async => await _navigateToToko(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}