import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:si_kasir/views/kasir/struk.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({
    Key? key,
    required this.selectedProducts,
    required this.totalAmount,
  }) : super(key: key);

  final List<Map<String, dynamic>> selectedProducts;
  final double totalAmount;

  @override
  _TransaksiScreenState createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  String selectedMethod = '';
  final TextEditingController nameController = TextEditingController();
  final TextEditingController initialPaymentController =
      TextEditingController();
  final TextEditingController remainingDebtController = TextEditingController();
  final TextEditingController cashAmountController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  double? changeAmount;
  double? remainingDebt;
  bool _isLoading = false; // Added loading state
  String? qrisUrl;

  @override
  void dispose() {
    nameController.dispose();
    initialPaymentController.dispose();
    remainingDebtController.dispose();
    cashAmountController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Fungsi untuk memformat uang ke format Indonesia
  String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Fungsi untuk mengubah format uang ke angka biasa
  double parseCurrency(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  void calculateChange() {
    if (cashAmountController.text.isNotEmpty) {
      double cashAmount = parseCurrency(cashAmountController.text);
      setState(() {
        changeAmount = cashAmount - widget.totalAmount;
      });
    }
  }

  void calculateRemainingDebt() {
    if (initialPaymentController.text.isNotEmpty) {
      double initialPayment = parseCurrency(initialPaymentController.text);
      setState(() {
        remainingDebt = widget.totalAmount - initialPayment;
        remainingDebtController.text = formatCurrency(remainingDebt ?? 0);
      });
    }
  }

  // Added function for exact payment
  void setExactPayment() {
    setState(() {
      cashAmountController.text = formatCurrency(widget.totalAmount);
      changeAmount = 0;
    });
  }

  String generateTransactionId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomString =
        List.generate(3, (index) => chars[random.nextInt(chars.length)]).join();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'TRX-$timestamp-$randomString';
  }

  Future<void> _loadUserEmailAndQRIS() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
      });

      // Ambil URL QRIS dari Firestore
      final tokoDoc = await FirebaseFirestore.instance
          .collection('toko')
          .where('email', isEqualTo: user.email)
          .get();

      if (tokoDoc.docs.isNotEmpty) {
        final tokoData = tokoDoc.docs.first.data();
        setState(() {
          qrisUrl = tokoData['qris_image'];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserEmailAndQRIS();
  }

  Future<void> saveTransactionToFirestore(String transactionId) async {
    final transactionData = {
      'email': _emailController.text.isNotEmpty
          ? _emailController.text
          : 'tidak-diketahui@example.com',
      'transactionId': transactionId,
      'products':
          widget.selectedProducts.isNotEmpty ? widget.selectedProducts : [],
      'totalAmount': widget.totalAmount,
      'paymentMethod':
          selectedMethod.isNotEmpty ? selectedMethod : 'tidak-diketahui',
      'customerName': nameController.text.isNotEmpty
          ? nameController.text
          : 'Tidak Diketahui',
      'initialPayment': parseCurrency(initialPaymentController.text),
      'remainingDebt': remainingDebt ?? 0,
      'cashAmount': parseCurrency(cashAmountController.text),
      'changeAmount': changeAmount ?? 0,
      'timestamp': FieldValue.serverTimestamp(),
      'status': (selectedMethod == 'langsung' || selectedMethod == 'non-tunai')
          ? 'Lunas'
          : 'Belum Lunas',
    };

    // Simpan transaksi ke Firestore
    await FirebaseFirestore.instance
        .collection('transaksi')
        .doc(transactionId)
        .set(transactionData);

    // Kurangi stok produk yang dibeli
    for (var product in widget.selectedProducts) {
      final productId = product['id'];
      final quantityPurchased = product['quantity'];

      final productDoc = await FirebaseFirestore.instance
          .collection('produk')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        final currentStock = productDoc.get('stok') ?? 0;
        final newStock = currentStock - quantityPurchased;

        await FirebaseFirestore.instance
            .collection('produk')
            .doc(productId)
            .update({
          'stok': newStock,
        });
      }
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pembayaran ${formatCurrency(widget.totalAmount)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Konfirmasi pembayaran dengan total telah dibayarkan oleh pembeli.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Color(0xFF133E87)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF133E87),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF133E87),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                final transactionId = generateTransactionId();
                                await saveTransactionToFirestore(transactionId);
                                Navigator.pop(context);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StrukScreen(
                                      transactionId: transactionId,
                                    ),
                                  ),
                                );
                              },
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'OK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenQRIS(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('QRIS'),
          ),
          body: Center(
            child: qrisUrl != null
                ? Image.network(
                    qrisUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error, color: Colors.red);
                    },
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget buildPaymentMethod(String title, String subtitle, String method) {
    bool isSelected = selectedMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMethod = method;
          cashAmountController.clear();
          nameController.clear();
          initialPaymentController.clear();
          remainingDebtController.clear();
          changeAmount = null;
          remainingDebt = null;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF133E87) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF133E87) : Colors.grey,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isSelected ? Colors.white : const Color(0xFF133E87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCashPaymentForm() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pembayaran Tunai',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF133E87),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: cashAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            onChanged: (value) => calculateChange(),
            decoration: InputDecoration(
              labelText: 'Jumlah Uang',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon:
                  const Icon(Icons.payments_outlined, color: Color(0xFF133E87)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF133E87)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Added "Uang Pas" button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: Color(0xFF133E87)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setExactPayment();
              },
              child: const Text(
                'Uang Pas',
                style: TextStyle(
                  color: Color(0xFF133E87),
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (changeAmount != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kembalian: ${formatCurrency(changeAmount ?? 0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  Widget buildDebtForm() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Piutang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF133E87),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nama Pembeli',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon:
                  const Icon(Icons.person_outline, color: Color(0xFF133E87)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF133E87)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: initialPaymentController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            onChanged: (value) => calculateRemainingDebt(),
            decoration: InputDecoration(
              labelText: 'Pembayaran Awal',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon:
                  const Icon(Icons.payments_outlined, color: Color(0xFF133E87)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF133E87)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: remainingDebtController,
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Sisa Hutang',
              labelStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                  color: Color(0xFF133E87)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF133E87)),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF133E87), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pastikan data piutang sudah benar sebelum melanjutkan transaksi',
                    style: TextStyle(
                      color: Color(0xFF133E87),
                      fontSize: 13,
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

  Widget buildQRISSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showFullScreenQRIS(context),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: qrisUrl != null
                    ? Image.network(
                        qrisUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error, color: Colors.red);
                        },
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ketuk QR Code untuk memperbesar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSelectedPaymentContent() {
    switch (selectedMethod) {
      case 'langsung':
        return buildCashPaymentForm();
      case 'non-tunai':
        return buildQRISSection();
      case 'piutang':
        return buildDebtForm();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget buildOrderDetail(String name, String qty, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
                Text(
                  qty,
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenPadding = mediaQuery.padding;
    final availableHeight =
        screenHeight - screenPadding.top - screenPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF133E87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Transaksi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: availableHeight - AppBar().preferredSize.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      buildPaymentMethod(
                        'Bayar Langsung',
                        'Pembeli langsung melakukan pembayaran',
                        'langsung',
                      ),
                      buildPaymentMethod(
                        'Pembayaran Non-Tunai',
                        'Pembeli melakukan pembayaran non-tunai',
                        'non-tunai',
                      ),
                      buildPaymentMethod(
                        'Piutang',
                        'Bayar nanti (piutang)',
                        'piutang',
                      ),
                      buildSelectedPaymentContent(),
                      const SizedBox(height: 24),
                      const Text(
                        'Rincian Pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.selectedProducts.map((product) {
                        return buildOrderDetail(
                          product['name'],
                          '${formatCurrency(product['price'])} x ${product['quantity']}',
                          formatCurrency(
                              product['price'] * product['quantity']),
                        );
                      }).toList(),
                      const Divider(thickness: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            formatCurrency(widget.totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      mediaQuery.viewInsets.bottom + 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedMethod.isEmpty
                              ? Colors.grey[400]
                              : const Color(0xFF133E87),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _isLoading || selectedMethod.isEmpty
                            ? null
                            : () {
                                // Validation logic
                                if (selectedMethod.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Pilih metode pembayaran terlebih dahulu'),
                                      backgroundColor: Color(0xFF133E87),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                // Cash payment validation
                                if (selectedMethod == 'langsung') {
                                  if (cashAmountController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Masukkan jumlah uang'),
                                        backgroundColor: Color(0xFF133E87),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  double cashAmount =
                                      parseCurrency(cashAmountController.text);
                                  if (cashAmount < widget.totalAmount) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Jumlah uang kurang dari total belanja'),
                                        backgroundColor: Color(0xFF133E87),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Debt payment validation
                                if (selectedMethod == 'piutang') {
                                  if (nameController.text.isEmpty ||
                                      initialPaymentController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Mohon lengkapi semua form piutang'),
                                        backgroundColor: Color(0xFF133E87),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  double initialPayment = parseCurrency(
                                      initialPaymentController.text);
                                  if (initialPayment >= widget.totalAmount) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Pembayaran awal melebihi total belanja. Gunakan metode Bayar Langsung'),
                                        backgroundColor: Color(0xFF133E87),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Show confirmation dialog
                                _showConfirmationDialog();
                              },
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Konfirmasi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
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
      ),
    );
  }
}

// Formatter untuk input uang
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus semua karakter non-digit
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Format ke dalam format mata uang
    if (newText.isNotEmpty) {
      final value = int.parse(newText);
      newText =
          'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}