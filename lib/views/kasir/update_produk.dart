import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class UpdateProdukScreen extends StatefulWidget {
  final String productId;

  const UpdateProdukScreen({super.key, required this.productId});

  @override
  _UpdateProdukScreenState createState() => _UpdateProdukScreenState();
}

class _UpdateProdukScreenState extends State<UpdateProdukScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _barcodeResult;
  bool _isLoading = false;
  bool _isFetching = true;
  String? selectedKategori;
  String? _existingImageUrl;

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

  @override
  void initState() {
    super.initState();
    _fetchProductData();
  }

  Future<void> _fetchProductData() async {
    try {
      final docSnapshot =
          await _firestore.collection('produk').doc(widget.productId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _namaProdukController.text = data['namaProduk'];
          _hargaBeliController.text = _formatCurrency(data['hargaBeli'].toString());
          _hargaJualController.text = _formatCurrency(data['hargaJual'].toString());
          _stokController.text = data['stok'].toString();
          _deskripsiController.text = data['deskripsi'];
          _kategoriController.text = data['kategori'];
          _barcodeResult = data['barcode'];
          selectedKategori = data['kategori'];

          // Tambahkan base URL jika gambarUrl hanya berisi path
          final imagePath = data['gambarUrl'];
          if (imagePath != null && !imagePath.startsWith('http')) {
            _existingImageUrl = 'https://res.cloudinary.com/dlu5vj2x6/image/upload/$imagePath';
          } else {
            _existingImageUrl = imagePath;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk tidak ditemukan!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data produk')),
      );
      Navigator.pop(context);
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  // Format angka dengan tanda pemisah ribuan
  String _formatCurrency(String value) {
    if (value.isEmpty) return '';
    final intValue = int.parse(value.replaceAll('.', ''));
    return intValue.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
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

  Future<void> _updateProduct() async {
    final String namaProduk = _namaProdukController.text.trim();
    final String hargaBeli = _hargaBeliController.text.replaceAll('.', '').trim(); 
    final String hargaJual = _hargaJualController.text.replaceAll('.', '').trim(); 
    final String stok = _stokController.text.trim();
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
      String? imageUrl = _existingImageUrl;

      if (_imageFile != null) {
        imageUrl = await _uploadImageToCloudinary(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      final productData = {
        'namaProduk': namaProduk,
        'hargaBeli': int.parse(hargaBeli), // Simpan sebagai integer
        'hargaJual': int.parse(hargaJual), // Simpan sebagai integer
        'stok': int.parse(stok),
        'deskripsi': deskripsi,
        'kategori': kategori,
        'barcode': _barcodeResult,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        productData['gambarUrl'] = imageUrl;
      }

      await _firestore.collection('produk').doc(widget.productId).update(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk berhasil diperbarui!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Gagal memperbarui produk')),
      );
      print('Error updating product: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          'Update Produk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: _isFetching
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF133E87)),
              ),
            )
          : Stack(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        double containerWidth = constraints.maxWidth;
        double containerHeight = containerWidth * 0.75;
        containerHeight = containerHeight.clamp(0.0, 400.0);

        return Container(
          margin: EdgeInsets.all(20),
          width: containerWidth,
          height: containerHeight,
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
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _imageFile != null
                    ? Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildErrorContainer();
                        },
                      )
                    : _existingImageUrl != null
                        ? Image.network(
                            _existingImageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: Color(0xFF133E87),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return _buildErrorContainer();
                            },
                          )
                        : _buildPlaceholderContainer(),
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
      },
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.red[400],
          ),
          SizedBox(height: 8),
          Text(
            'Gagal memuat gambar',
            style: TextStyle(
              color: Colors.red[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap untuk memilih gambar baru',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
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
                isCurrency: true, // Tambahkan parameter ini
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
                isCurrency: true, // Tambahkan parameter ini
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
            onTap: () {
              // Navigate to barcode scanner
            },
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
                      onPressed: () {
                        // Navigate to barcode scanner
                      },
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
    bool isCurrency = false, // Tambahkan parameter untuk menandai field harga
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
              prefixIcon: icon != null ? Icon(icon, color: Color(0xFF133E87)) : null,
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
          onTap: _updateProduct,
          child: Center(
            child: Text(
              'Simpan Perubahan',
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