import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Model untuk data transaksi
class TransactionDetail {
  final String transactionId;
  final String date;
  final double amount;
  final String itemName;
  final int quantity;
  final double itemPrice;
  final String paymentMethod;
  final String status;

  TransactionDetail({
    required this.transactionId,
    required this.date,
    required this.amount,
    required this.itemName,
    required this.quantity,
    required this.itemPrice,
    required this.paymentMethod,
    required this.status,
  });

  factory TransactionDetail.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp timestamp = data['timestamp'] as Timestamp;
    final DateTime transactionDate = timestamp.toDate();
    final formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(transactionDate);

    // Handle item data - assuming there's at least one item in the transaction
    final List<dynamic> items = data['products'] ?? [];
    String itemName = 'Tidak ada item';
    int quantity = 0;
    double itemPrice = 0;

    if (items.isNotEmpty) {
      final firstItem = items[0];
      itemName = firstItem['name'] ?? 'Tidak ada nama';
      quantity = firstItem['quantity'] ?? 0;
      itemPrice = (firstItem['price'] ?? 0).toDouble();
    }

    return TransactionDetail(
      transactionId: data['transactionId'] ?? doc.id,
      date: formattedDate,
      amount: (data['totalAmount'] ?? 0).toDouble(),
      itemName: itemName,
      quantity: quantity,
      itemPrice: itemPrice,
      paymentMethod: data['paymentMethod'] == 'non-tunai' ? 'Non-Tunai' : data['paymentMethod'] ?? 'Non-Tunai',
      status: data['status'] ?? 'Lunas',
    );
  }
}

class DetailNonTunaiScreen extends StatefulWidget {
  final String transactionId;

  const DetailNonTunaiScreen({
    Key? key,
    required this.transactionId,
  }) : super(key: key);

  @override
  _DetailNonTunaiScreenState createState() => _DetailNonTunaiScreenState();
}

class _DetailNonTunaiScreenState extends State<DetailNonTunaiScreen> {
  TransactionDetail? _transactionDetail;
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Format currency dengan pemisah ribuan (.)
  final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadTransactionDetail();
  }

  Future<void> _loadTransactionDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final DocumentSnapshot transactionDoc = await _firestore
          .collection('transaksi')
          .doc(widget.transactionId)
          .get();

      if (transactionDoc.exists) {
        setState(() {
          _transactionDetail = TransactionDetail.fromDocument(transactionDoc);
          _isLoading = false;
        });
      } else {
        // Handle case where document doesn't exist
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaksi tidak ditemukan')),
        );
        setState(() {
          _isLoading = false;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detail Transaksi Non-Tunai',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF133E87),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTransactionDetailCard(),
                    const SizedBox(height: 16.0),
                    _buildItemDetailCard(),
                    const SizedBox(height: 16.0),
                    _buildPaymentInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTransactionDetailCard() {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              Icons.receipt,
              'Nomor Transaksi',
              _transactionDetail!.transactionId,
            ),
            Divider(color: Colors.grey.shade300),
            _buildDetailRow(
              Icons.calendar_today,
              'Tanggal',
              _transactionDetail!.date,
            ),
            Divider(color: Colors.grey.shade300),
            _buildDetailRow(
              Icons.attach_money,
              'Total Pembayaran',
              currencyFormatter.format(_transactionDetail!.amount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF133E87), size: 24),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 4.0),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetailCard() {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _transactionDetail!.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_transactionDetail!.quantity} x ${currencyFormatter.format(_transactionDetail!.itemPrice)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  currencyFormatter.format(_transactionDetail!.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            Divider(color: Colors.grey.shade300, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  currencyFormatter.format(_transactionDetail!.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF133E87),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metode Pembayaran',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Text(
                  _transactionDetail!.paymentMethod,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Text(
                  _transactionDetail!.status,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}