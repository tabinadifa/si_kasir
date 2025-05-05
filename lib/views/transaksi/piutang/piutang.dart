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
  String selectedStatus = "Semua"; // Default filter adalah "Semua"
  late String selectedMonth;
  late int selectedYear;
  final int currentYear = DateTime.now().year;
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