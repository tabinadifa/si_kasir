import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:si_kasir/views/kasir/pindai_produk.dart';

class CreateProdukScreen extends StatefulWidget {
  const CreateProdukScreen({super.key, required String productId});

  @override
  _CreateProdukScreenState createState() => _CreateProdukScreenState();
}

class _CreateProdukScreenState extends State<CreateProdukScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _barcodeResult;
  bool _isLoading = false;
  late String _productId;
  String? selectedKategori;

  // Initialize Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize Cloudinary
  final cloudinary = CloudinaryPublic('dlu5vj2x6', 'si_kasir', cache: false);

  // Controllers for form fields
  final TextEditingController _namaProdukController = TextEditingController();
  final TextEditingController _hargaBeliController = TextEditingController();
  final TextEditingController _hargaJualController = TextEditingController();
  final TextEditingController _stokController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _kategoriController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateProductId();
    _loadUserEmail();
  }

    Future<void> _loadUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
      });
    }
  }

  void _generateProductId() {
    // Generate a timestamp-based prefix
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Generate a random 4-character string
    String randomString = '';
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    for (int i = 0; i < 4; i++) {
      randomString += chars[random.nextInt(chars.length)];
    }

    // Combine timestamp and random string
    _productId = 'PRD-$timestamp-$randomString';
  }

  Widget _buildKategoriDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: selectedKategori,
        decoration: InputDecoration(
          labelText: 'Kategori',
          prefixIcon: const Icon(Icons.category_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'Makanan',
            child: Text('Makanan'),
          ),
          DropdownMenuItem(
            value: 'Minuman',
            child: Text('Minuman'),
          ),
          DropdownMenuItem(
            value: 'Lain-lain',
            child: Text('Lain-lain'),
          ),
        ],
        onChanged: (String? newValue) {
          setState(() {
            selectedKategori = newValue;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Pilih kategori';
          }
          return null;
        },
      ),
    );
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      // Return the full URL from Cloudinary
      return response.secureUrl;
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text('Pilih Sumber Foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xFF133E87)),
                title: Text('Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Color(0xFF133E87)),
                title: Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToScanScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PindaiProdukScreen()),
    );

    if (result != null) {
      setState(() {
        _barcodeResult = result;
      });
    }
  }

  Future<void> _saveProduct() async {
    final String namaProduk = _namaProdukController.text.trim();
    final String hargaBeli = _hargaBeliController.text.replaceAll('.', '').trim(); // Hapus tanda pemisah ribuan
    final String hargaJual = _hargaJualController.text.replaceAll('.', '').trim(); // Hapus tanda pemisah ribuan
    final String stok = _stokController.text.trim();
    final String email = _emailController.text.trim();
    final String deskripsi = _deskripsiController.text.trim();
    final String kategori = selectedKategori ?? '';

    // Validasi input
    if (namaProduk.isEmpty ||
        hargaBeli.isEmpty ||
        hargaJual.isEmpty ||
        stok.isEmpty ||
        deskripsi.isEmpty ||
        kategori.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Harap isi semua data!')),
      );
      return;
    }

    // Validasi angka
    try {
      int.parse(hargaBeli);
      int.parse(hargaJual);
      int.parse(stok);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Format angka tidak valid!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImageToCloudinary(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Create product data
      final productData = {
        'productId': _productId,
        'namaProduk': namaProduk,
        'hargaBeli': int.parse(hargaBeli), 
        'hargaJual': int.parse(hargaJual), 
        'stok': int.parse(stok),
        'email': email,
        'deskripsi': deskripsi,
        'kategori': kategori,
        'barcode': _barcodeResult,
        'gambarUrl': imageUrl, 
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore using productId as document ID
      await _firestore.collection('produk').doc(_productId).set(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk berhasil disimpan!')),
      );

      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Gagal menyimpan produk')),
      );
      print('Error saving product: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _namaProdukController.clear();
    _hargaBeliController.clear();
    _hargaJualController.clear();
    _stokController.clear();
    _deskripsiController.clear();
    _kategoriController.clear();
    setState(() {
      _imageFile = null;
      _barcodeResult = null;
      _generateProductId(); // Generate new ID for next product
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF133E87),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tambah Produk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey[50],
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildImagePicker(),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display Product ID
                        Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID Produk',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF133E87),
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _productId,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildForm(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF133E87)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      height: 200,
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                _imageFile!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 40,
                    color: Color(0xFF133E87),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'TAMBAH FOTO',
                    style: TextStyle(
                      color: Color(0xFF133E87),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _showImageSourceDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          'Nama Produk',
          'Contoh: Mie',
          icon: Icons.shopping_bag_outlined,
          controller: _namaProdukController,
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Harga Beli',
                '0',
                icon: Icons.price_change_outlined,
                controller: _hargaBeliController,
                keyboardType: TextInputType.number,
                isCurrency: true, // Tambahkan parameter untuk format ribuan
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: _buildTextField(
                'Harga Jual',
                '0',
                icon: Icons.attach_money,
                controller: _hargaJualController,
                keyboardType: TextInputType.number,
                isCurrency: true, // Tambahkan parameter untuk format ribuan
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildTextField(
          'Stok',
          'Stok Produk',
          icon: Icons.inventory_2_outlined,
          controller: _stokController,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 20),
        _buildTextField(
          'Deskripsi',
          'Deskripsikan Produk Kamu',
          icon: Icons.description_outlined,
          maxLines: 3,
          controller: _deskripsiController,
        ),
        SizedBox(height: 20),
        _buildKategoriDropdown(),
        SizedBox(height: 20),
        _buildBarcodeField(),
        SizedBox(height: 30),
        _buildSaveButton(context),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barcode',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF133E87),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: _navigateToScanScreen,
            child: Container(
              height: 55,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: _barcodeResult != null
                    ? Border.all(color: Color(0xFF133E87), width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Color(0xFF133E87)),
                  SizedBox(width: 10),
                  Expanded(
                    child: _barcodeResult != null
                        ? Text(
                            _barcodeResult!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          )
                        : Text(
                            'Pindai Barcode',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                  if (_barcodeResult != null)
                    TextButton(
                      onPressed: _navigateToScanScreen,
                      child: Text(
                        'Ganti',
                        style: TextStyle(
                          color: Color(0xFF133E87),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextEditingController? controller,
    bool isCurrency = false, // Tambahkan parameter untuk format ribuan
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF133E87),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: isCurrency
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorInputFormatter(),
                  ]
                : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon:
                  icon != null ? Icon(icon, color: Color(0xFF133E87)) : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF133E87), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [Color(0xFF133E87), Color(0xFF1E56B1)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF133E87).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _saveProduct,
          child: Center(
            child: Text(
              'Simpan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    _deskripsiController.dispose();
    _emailController.dispose();
    _kategoriController.dispose();
    super.dispose();
  }
}

// Formatter untuk tanda pemisah ribuan
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus semua karakter non-digit
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Format dengan tanda pemisah ribuan
    if (newText.isNotEmpty) {
      final intValue = int.parse(newText);
      newText = intValue.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}