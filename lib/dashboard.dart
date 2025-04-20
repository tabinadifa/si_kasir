import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:si_kasir/views/laporan/omzetpertahun.dart';
import 'package:si_kasir/views/laporan/produkterjual.dart';
import 'package:si_kasir/views/toko/read_toko.dart';
import 'package:si_kasir/views/kasir/daftar_produk.dart';
import 'package:si_kasir/views/laporan/laporan.dart';
import 'package:si_kasir/views/toko/create_toko.dart';
import 'package:si_kasir/views/laporan/totaltransaksi.dart';
import 'package:si_kasir/views/transaksi/nontunai/nontunai.dart';
import 'package:si_kasir/views/transaksi/piutang/piutang.dart';
import 'package:si_kasir/views/transaksi/transaksi.dart';
import 'package:si_kasir/views/transaksi/tunai/tunai.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  // Build sidebar menu - IMPROVED
  Widget _buildSidebar() {
    return Drawer(
      elevation: 0,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header gradient container with profile
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF133E87), Color(0xFF1E56B1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile image with animated container
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 45,
                      child: isLoadingProfile 
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF133E87)),
                          )
                        : profileImageUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: const Color(0xFF133E87),
                                      value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.store,
                                    color: Color(0xFF133E87),
                                    size: 45,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.store,
                              color: Color(0xFF133E87),
                              size: 45,
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // App name with fading styling
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Masyallah Store',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Scrollable menu items
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kasir Section
                  _buildSectionHeader('KASIR'),
                  _buildSidebarItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Daftar Produk',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DaftarProdukScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Laporan Section
                  _buildSectionHeader('LAPORAN'),
                  _buildSidebarItem(
                    icon: Icons.receipt_long,
                    title: 'Laporan',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LaporanScreen()),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.account_balance_wallet,
                    title: 'Total Transaksi',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TotalTransaksiScreen()),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.inventory,
                    title: 'Produk Terjual',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProdukTerjualScreen()),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.monetization_on,
                    title: 'Omzet Pertahun',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => OmzetPertahunScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Transaksi Section
                  _buildSectionHeader('TRANSAKSI'),
                  _buildSidebarItem(
                    icon: Icons.history,
                    title: 'Riwayat Transaksi',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RiwayatTransaksiScreen()),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.payments,
                    title: 'Transaksi Tunai',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TransaksiTunaiScreen()),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.credit_card,
                    title: 'Transaksi Non Tunai',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TransaksiNonTunaiScreen()),
                      );
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.attach_money,
                    title: 'Kelola Piutang',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DataPiutangScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Toko Section
                  _buildSectionHeader('TOKO'),
                  _buildSidebarItem(
                    icon: Icons.store,
                    title: 'Toko',
                    onTap: () async {
                      Navigator.pop(context); // Close drawer
                      await _navigateToToko(context);
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(thickness: 1),
                  const SizedBox(height: 8),
                  
                  // Help Center with special styling
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF133E87), Color(0xFF1E56B1)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _launchHelpCenter();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.help_outline,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'Pusat Bantuan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer with version info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png', // Asumsikan ada logo di assets
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.point_of_sale,
                      color: Color(0xFF133E87),
                      size: 24,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '© 2025 SiKasir App',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section header builder
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF133E87),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF133E87),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar item builder - IMPROVED
  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF133E87).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon, 
                    color: const Color(0xFF133E87),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2D3748),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      key: _scaffoldKey,
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
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF133E87)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildSidebar(),
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: () async {
          // Panggil fungsi refresh untuk memuat ulang data
          await _loadProfileData();
          await _loadSaldoData();
        },
        child: SingleChildScrollView(
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
      ),
    );
  }
}