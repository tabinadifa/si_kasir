import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class DetailPiutangScreen extends StatefulWidget {
  final String transactionId;

  const DetailPiutangScreen({Key? key, required this.transactionId})
      : super(key: key);

  @override
  _DetailPiutangScreenState createState() => _DetailPiutangScreenState();
}

class _DetailPiutangScreenState extends State<DetailPiutangScreen> {
  final List<String> statusOptions = ['Belum Lunas', 'Lunas'];
  String _statusPembayaran = 'Belum Lunas';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  
  // Controller untuk initialPayment
  final TextEditingController _initialPaymentController = TextEditingController();
  
  Map<String, dynamic>? _transactionData;
  bool _isLoading = true;
  double _initialPayment = 0;
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
  }

  @override
  void dispose() {
    _initialPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactionData() async {
    try {
      final DocumentSnapshot transactionDoc = await _firestore
          .collection('transaksi')
          .doc(widget.transactionId)
          .get();

      if (transactionDoc.exists) {
        setState(() {
          _transactionData = transactionDoc.data() as Map<String, dynamic>;
          _statusPembayaran = _transactionData!['status'] ?? 'Belum Lunas';
          _initialPayment = (_transactionData!['initialPayment'] ?? 0).toDouble();
          _totalAmount = (_transactionData!['totalAmount'] ?? 0).toDouble();
          
          // Set nilai awal dengan format Rupiah
          _initialPaymentController.text = currencyFormatter.format(_initialPayment).replaceAll('Rp', '').trim();
          
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaksi tidak ditemukan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk memeriksa apakah initialPayment sama dengan totalAmount
  void _checkPaymentStatus() {
    if (_initialPayment >= _totalAmount) {
      setState(() {
        _statusPembayaran = 'Lunas';
      });
    } else {
      setState(() {
        _statusPembayaran = 'Belum Lunas';
      });
    }
  }

  // Fungsi untuk mengubah string format Rupiah menjadi double
  double _parseRupiahToDouble(String rupiahString) {
    // Hapus semua karakter non-digit
    String digitsOnly = rupiahString.replaceAll(RegExp(r'[^\d]'), '');
    
    // Konversi ke double
    if (digitsOnly.isEmpty) {
      return 0;
    }
    return double.parse(digitsOnly);
  }

  // Fungsi untuk memformat angka ke dalam format Rupiah
  String _formatToRupiah(String text) {
    if (text.isEmpty) return '';
    
    double value = _parseRupiahToDouble(text);
    return currencyFormatter.format(value).replaceAll('Rp', '').trim();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy', 'id_ID').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detail Piutang',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF133E87),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTransactionDetailCard(),
                    SizedBox(height: 16.0),
                    _buildItemDetailCard(),
                    SizedBox(height: 16.0),
                    _buildPaymentInfoCard(),
                    SizedBox(height: 24.0),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTransactionDetailCard() {
    final Timestamp timestamp = _transactionData!['timestamp'] as Timestamp;
    final formattedDate = _formatTimestamp(timestamp);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              Icons.receipt,
              'Nomor Transaksi',
              _transactionData!['transactionId'] ?? 'Tidak Diketahui',
            ),
            Divider(color: Colors.grey.shade300),
            _buildDetailRow(
              Icons.calendar_today,
              'Tanggal',
              formattedDate,
            ),
            Divider(color: Colors.grey.shade300),
            _buildDetailRow(
              Icons.person,
              'Nama Pembeli',
              _transactionData!['customerName'] ?? 'Tidak Diketahui',
            ),
            Divider(color: Colors.grey.shade300),
            _buildDetailRow(
              Icons.attach_money,
              'Total Pembayaran',
              currencyFormatter.format(_totalAmount),
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
          Icon(icon, color: Color(0xFF133E98), size: 24),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                SizedBox(height: 4.0),
                Text(
                  value,
                  style: TextStyle(
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
    final List<dynamic> products = _transactionData!['products'] ?? [];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16.0),
            ...products.map((product) {
              final String name = product['name'] ?? 'Tidak Diketahui';
              final int quantity = product['quantity'] ?? 0;
              final double price = (product['price'] ?? 0).toDouble();
              final double total = quantity * price;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$quantity x ${currencyFormatter.format(price)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        currencyFormatter.format(total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Divider(color: Colors.grey.shade300, height: 24),
                ],
              );
            }).toList(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  currencyFormatter.format(_totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF133E98),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16.0),
            // Tambahkan input untuk initialPayment dengan format Rupiah
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pembayaran Awal',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Container(
                  width: 150,
                  child: TextField(
                    controller: _initialPaymentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      prefixText: 'Rp ',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      // Format input sebagai rupiah
                      String formattedValue = _formatToRupiah(value);
                      
                      // Perbarui controller tanpa rekursi
                      _initialPaymentController.value = TextEditingValue(
                        text: formattedValue,
                        selection: TextSelection.collapsed(offset: formattedValue.length),
                      );
                      
                      // Update nilai initialPayment
                      setState(() {
                        _initialPayment = _parseRupiahToDouble(formattedValue);
                        _checkPaymentStatus();
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metode Pembayaran',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Text(
                  _transactionData!['paymentMethod'] ?? 'Tidak Diketahui',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusPembayaran,
                      items: statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: status == 'Lunas' ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _statusPembayaran = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.0),
            // Menampilkan sisa pembayaran
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sisa Pembayaran',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                Text(
                  currencyFormatter.format(_totalAmount - _initialPayment > 0 ? _totalAmount - _initialPayment : 0),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _totalAmount - _initialPayment > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            try {
              // Simpan nilai asli (angka) ke Firestore
              await _firestore
                  .collection('transaksi')
                  .doc(widget.transactionId)
                  .update({
                'status': _statusPembayaran,
                'initialPayment': _initialPayment, // Simpan sebagai angka biasa
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Data berhasil diperbarui')),
              );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF133E87),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            'Simpan',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}