import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:si_kasir/views/transaksi/nontunai/detail_nontunai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransaksiNonTunaiScreen extends StatefulWidget {
  @override
  _TransaksiNonTunaiScreenState createState() =>
      _TransaksiNonTunaiScreenState();
}

class _TransaksiNonTunaiScreenState extends State<TransaksiNonTunaiScreen> {
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
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  bool isLoading = false;
  List<Map<String, dynamic>> transactions = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    selectedMonth = months[DateTime.now().month - 1];
    selectedYear = currentYear;
    for (int year = currentYear; year >= currentYear - 5; year--) {
      years.add(year);
    }
    fetchTransactions();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
      });
      fetchTransactions();
    }
  }

  Future<void> fetchTransactions() async {
    if (userEmail == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Convert selected month to numeric value (1-12)
      int monthIndex = months.indexOf(selectedMonth) + 1;

      // Create date range for selected month and year
      DateTime startDate = DateTime(selectedYear, monthIndex, 1);
      DateTime endDate = monthIndex < 12
          ? DateTime(selectedYear, monthIndex + 1, 1)
          : DateTime(selectedYear + 1, 1, 1);

      // Query Firestore for non-cash transactions in the date range
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('transaksi')
          .where('email', isEqualTo: userEmail)
          .where('paymentMethod', isEqualTo: 'non-tunai')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThan: endDate)
          .orderBy('timestamp', descending: true)
          .get();

      // Convert query results to List
      List<Map<String, dynamic>> fetchedTransactions = querySnapshot.docs
          .map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            // Add the document ID to the data map
            data['id'] = doc.id;
            return data;
          })
          .toList();

      setState(() {
        transactions = fetchedTransactions;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching transactions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: Colors.white, size: screenWidth * 0.06),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Transaksi Non-Tunai',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: screenWidth * 0.045,
          ),
        ),
        backgroundColor: Color(0xFF133E87),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    selectedMonth,
                    months,
                    (val) {
                      setState(() => selectedMonth = val!);
                      fetchTransactions();
                    },
                    context,
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildDropdown(
                    selectedYear.toString(),
                    years.map((e) => e.toString()).toList(),
                    (val) {
                      setState(() => selectedYear = int.parse(val!));
                      fetchTransactions();
                    },
                    context,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshTransactions,
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : transactions.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada transaksi non-tunai pada periode ini',
                              style: TextStyle(fontSize: screenWidth * 0.04),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(screenWidth * 0.03),
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              return _buildTransactionCard(
                                  transactions[index], context);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshTransactions() async {
    await fetchTransactions();
  }

  Widget _buildDropdown(
      String value, List<String> items, ValueChanged<String?> onChanged, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.005,
      ),
      decoration: BoxDecoration(
        color: Color(0xFF133E87),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down,
              color: Colors.white, size: screenWidth * 0.06),
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.04,
          ),
          dropdownColor: Color(0xFF133E87),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.04,
                  ),
                ));
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
      Map<String, dynamic> transaction, BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Format date from timestamp
    String formattedDate = '';
    if (transaction['timestamp'] != null) {
      Timestamp timestamp = transaction['timestamp'] as Timestamp;
      DateTime dateTime = timestamp.toDate();
      formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
    }

    // Format amount
    String formattedAmount =
        currencyFormatter.format(transaction['totalAmount'] ?? 0);

    // Get transaction status
    String status = transaction['status'] ?? 'Berhasil';

    // Get transaction ID
    String transactionId = transaction['transactionId'] ?? transaction['id'] ?? 'Unknown';

    // Define status color
    Color statusColor = status == 'Berhasil' ? Colors.green : Colors.green;

    // Define text style for info items (date, QRIS, amount)
    TextStyle infoTextStyle = TextStyle(
      color: Colors.black87,
      fontSize: screenWidth * 0.035,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DetailNonTunaiScreen(transactionId: transactionId),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          side: BorderSide(
              color: Color(0xFFE0E0E0), width: screenWidth * 0.002),
        ),
        elevation: 4,
        shadowColor: Colors.black26,
        margin: EdgeInsets.only(bottom: screenHeight * 0.02),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF5F5F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
          ),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        transactionId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.04,
                          color: Color(0xFF133E87),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenHeight * 0.005,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(screenWidth * 0.01),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: screenWidth * 0.03,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.015),
                Divider(color: Colors.grey.shade300, height: screenHeight * 0.002),
                SizedBox(height: screenHeight * 0.015),

                // Date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: screenWidth * 0.045,
                      color: Color(0xFF133E87),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      formattedDate,
                      style: infoTextStyle,
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),

                // Payment method
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: screenWidth * 0.045,
                      color: Color(0xFF133E87),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      'QRIS',
                      style: infoTextStyle,
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),

                // Amount
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: screenWidth * 0.045,
                      color: Color(0xFF133E87),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      formattedAmount,
                      style: infoTextStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}