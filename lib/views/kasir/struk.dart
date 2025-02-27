import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:si_kasir/dashboard.dart';

class StrukScreen extends StatefulWidget {
  final String transactionId;

  const StrukScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<StrukScreen> createState() => _StrukScreenState();
}

class _StrukScreenState extends State<StrukScreen> {
  String storeName = '';
  String storePhone = '';
  bool isLoading = true;
  Map<String, dynamic>? transactionData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Fetch store data
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('toko')
            .where('email', isEqualTo: user.email)
            .get();

        if (storeDoc.docs.isNotEmpty) {
          setState(() {
            storeName = storeDoc.docs.first.get('nama_toko') ?? 'Unnamed Store';
            storePhone = storeDoc.docs.first.get('phone') ?? '';
          });
        }

        // Fetch transaction data
        final transactionDoc = await FirebaseFirestore.instance
            .collection('transaksi')
            .doc(widget.transactionId)
            .get();

        if (transactionDoc.exists) {
          setState(() {
            transactionData = transactionDoc.data() as Map<String, dynamic>;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd-MM-yyyy HH:mm').format(date);
  }

  String _formatCurrency(double amount) {
    return 'Rp${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF133E87),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Struk Pembelian',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: isLoading || transactionData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 32.0,
                        ),
                        child: Column(
                          children: [
                            // Header Section
                            Column(
                              children: [
                                const Icon(
                                  Icons.receipt,
                                  size: 40,
                                  color: Color(0xFF133E87),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF133E87),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  storePhone,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Transaction Info
                            _buildInfoRow('Nomor Transaksi', transactionData!['transactionId']),
                            _buildInfoRow('Tanggal', _formatDateTime(transactionData!['timestamp'] as Timestamp)),
                            _buildInfoRow('Metode Pembayaran', transactionData!['paymentMethod'] == 'langsung' 
                                ? 'Tunai' 
                                : transactionData!['paymentMethod'] == 'non-tunai' 
                                    ? 'QRIS'
                                    : 'Piutang'),

                            if (transactionData!['paymentMethod'] == 'piutang') ...[
                              _buildInfoRow('Nama Pembeli', transactionData!['customerName']),
                              _buildInfoRow('Pembayaran Awal', _formatCurrency(transactionData!['initialPayment'])),
                              _buildInfoRow('Sisa Hutang', _formatCurrency(transactionData!['remainingDebt'])),
                            ],

                            const Divider(height: 40, color: Colors.grey),

                            // Order Items
                            ...(transactionData!['products'] as List).map((item) => 
                              _buildOrderItem(
                                item['name'],
                                item['quantity'],
                                item['price'].toDouble(),
                                color: Colors.grey[800]!,
                              ),
                            ).toList(),

                            const Divider(height: 40, color: Colors.grey),

                            // Payment Summary
                            _buildTotalRow('Total Pesanan', _formatCurrency(transactionData!['totalAmount'])),
                            const SizedBox(height: 8),
                            _buildTotalRow('Total Pembayaran', _formatCurrency(transactionData!['totalAmount']),
                                isBold: true),

                            if (transactionData!['paymentMethod'] == 'langsung') ...[
                              const SizedBox(height: 8),
                              _buildTotalRow('Uang Tunai', 
                                _formatCurrency(transactionData!['cashAmount'])),
                              const SizedBox(height: 8),
                              _buildTotalRow('Kembalian', 
                                _formatCurrency(transactionData!['changeAmount']),
                                color: Colors.green),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Footer Message
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Text(
                        'Terima kasih telah berbelanja\n di $storeName',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardScreen(), 
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF133E87),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Kembali ke Dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(String name, int quantity, double price,
      {Color color = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity x ${_formatCurrency(price)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(price * quantity),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: color ?? const Color(0xFF133E87),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}