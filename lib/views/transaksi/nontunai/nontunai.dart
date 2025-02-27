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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Transaksi Non-Tunai',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF133E87),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    }
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    selectedYear.toString(),
                    years.map((e) => e.toString()).toList(),
                    (val) {
                      setState(() => selectedYear = int.parse(val!));
                      fetchTransactions();
                    }
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshTransactions,
                child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : transactions.isEmpty
                    ? Center(child: Text('Tidak ada transaksi non-tunai pada periode ini'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          return _buildTransactionCard(transactions[index]);
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
      String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF133E87),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: TextStyle(color: Colors.white),
          dropdownColor: Color(0xFF133E87),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(color: Colors.white),
                ));
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
  // Format date from timestamp
  String formattedDate = '';
  if (transaction['timestamp'] != null) {
    Timestamp timestamp = transaction['timestamp'] as Timestamp;
    DateTime dateTime = timestamp.toDate();
    formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
  }

  // Format amount
  String formattedAmount = currencyFormatter.format(transaction['totalAmount'] ?? 0);

  // Get transaction status
  String status = transaction['status'] ?? 'Berhasil';

  // Get transaction ID
  String transactionId = transaction['transactionId'] ?? transaction['id'] ?? 'Unknown';

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailNonTunaiScreen(transactionId: transactionId),
        ),
      );
    },
    child: Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      elevation: 6,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF5F5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        transactionId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF133E98),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(
                          color: status == 'Berhasil' ? Colors.green : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF133E98),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(color: Colors.grey),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                  SizedBox(width: 8),
                  Text(formattedDate),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 16, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('QRIS'),
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