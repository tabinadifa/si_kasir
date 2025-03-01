import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

const Color primaryBlue = Color(0xFF0A367E);
const Color secondaryBlue = Color(0xFF4A90E2);

class EditTokoScreen extends StatefulWidget {
  @override
  _EditTokoScreenState createState() => _EditTokoScreenState();
}

class _EditTokoScreenState extends State<EditTokoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryPublic _cloudinary = CloudinaryPublic('dlu5vj2x6', 'si_kasir', cache: false);
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input field
  final _namaTokoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String? _email; 
  String? _profileImageUrl; 
  String? _qrisImageUrl; 
  File? _profileImage;
  File? _qrisImage; 
  bool _isLoading = false; 
  String? _tokoId; 

  @override
  void initState() {
    super.initState();
    _loadUserData(); 
  }

  @override
  void dispose() {
    _namaTokoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Fungsi untuk memuat data toko dari Firestore
  Future<void> _loadUserData() async {
  User? user = _auth.currentUser;
  if (user != null) {
    setState(() {
      _email = user.email; 
      _emailController.text = _email ?? '';
    });

    // Mengambil data toko dari Firestore berdasarkan email
    QuerySnapshot tokoSnapshot = await _firestore
        .collection('toko')
        .where('email', isEqualTo: _email)
        .limit(1)
        .get();

    if (tokoSnapshot.docs.isNotEmpty) {
      DocumentSnapshot doc = tokoSnapshot.docs.first;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      setState(() {
        _tokoId = doc.id;
        _namaTokoController.text = data['nama_toko'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _profileImageUrl = data['profile_image'];
        _qrisImageUrl = data['qris_image'];
      });
    }
  }
}

  Future<void> _showImagePickerDialog({required bool isProfile}) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isProfile ? 'Pilih Foto Profil' : 'Pilih QRIS'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery, isProfile: isProfile);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Ambil Foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera, isProfile: isProfile);
                  },
                ),
                if ((isProfile && (_profileImage != null || _profileImageUrl != null)) || 
                    (!isProfile && (_qrisImage != null || _qrisImageUrl != null)))
                  ListTile(
                    leading: Icon(Icons.delete),
                    title: Text(isProfile ? 'Hapus Foto Profil' : 'Hapus QRIS'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        if (isProfile) {
                          _profileImage = null;
                          _profileImageUrl = null;
                        } else {
                          _qrisImage = null;
                          _qrisImageUrl = null;
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source, {required bool isProfile}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isProfile) {
            _profileImage = File(pickedFile.path);
          } else {
            _qrisImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile, String folder) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

Future<void> _submitForm() async {
  if (_formKey.currentState!.validate() && _tokoId != null) {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          ),
        );
      },
    );

    try {
      if (_profileImage != null) {
        _profileImageUrl = await _uploadToCloudinary(_profileImage!, 'profile_image');
      }

      if (_qrisImage != null) {
        _qrisImageUrl = await _uploadToCloudinary(_qrisImage!, 'qris_image');
      }

      // Save data to Firestore
      Map<String, dynamic> tokoData = {
        'nama_toko': _namaTokoController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'profile_image': _profileImageUrl ?? '', 
        'qris_image': _qrisImageUrl ?? '', 
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('toko').doc(_tokoId).update(tokoData);

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data berhasil diperbarui'),
          backgroundColor: primaryBlue,
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      // Close loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui data: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profil Toko',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
  padding: const EdgeInsets.all(20),
  child: GestureDetector(
    onTap: () => _showImagePickerDialog(isProfile: true),
    child: Container(
      width: 135,
      height: 135,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
        image: (_profileImage != null)
            ? DecorationImage(
                image: FileImage(_profileImage!),
                fit: BoxFit.cover,
              )
            : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(_profileImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
      ),
      child: (_profileImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  color: primaryBlue,
                  size: 50,
                ),
                SizedBox(height: 8),
                Text(
                  'Foto Profil',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : null,
    ),
  ),
),

                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Nama Toko', style: _formTitleStyle()),
                          SizedBox(height: 8),
                          buildInputField(
                            hintText: 'Masukkan nama toko',
                            icon: Icons.store_rounded,
                            controller: _namaTokoController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nama toko tidak boleh kosong';
                              }
                              if (value.length < 3) {
                                return 'Nama toko minimal 3 karakter';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25),
                          Text('Nomor Telepon', style: _formTitleStyle()),
                          SizedBox(height: 8),
                          buildInputField(
                            hintText: 'Masukkan nomor telepon',
                            icon: Icons.phone_rounded,
                            controller: _phoneController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nomor telepon tidak boleh kosong';
                              }
                              if (value.length < 10 || value.length > 13) {
                                return 'Nomor telepon harus 10-13 digit';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25),
                          Text('QRIS', style: _formTitleStyle()),
                          SizedBox(height: 12),
                          buildQrisUploader(),
                          SizedBox(height: 30),
                          buildButton('Simpan Perubahan', primaryBlue,
                              Icons.save_rounded, _submitForm),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  TextStyle _formTitleStyle() {
    return TextStyle(
      color: primaryBlue,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
  }

  Widget buildInputField({
    required String hintText,
    required IconData icon,
    TextEditingController? controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
          ),
          prefixIcon: Icon(icon, color: primaryBlue),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

Widget buildQrisUploader() {
  return GestureDetector(
    onTap: () => _showImagePickerDialog(isProfile: false),
    child: Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: (_qrisImage != null)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.file(
                _qrisImage!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          : (_qrisImageUrl != null && _qrisImageUrl!.isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.network(
                    _qrisImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_rounded,
                        color: primaryBlue,
                        size: 35,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Upload QRIS',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Tap untuk memilih file',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
    ),
  );
}


  Widget buildButton(
      String text, Color color, IconData icon, VoidCallback onPressed) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 24),
        label: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
      ),
    );
  }
}