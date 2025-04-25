import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:si_kasir/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';

const Color primaryBlue = Color(0xFF0A367E);
const Color secondaryBlue = Color(0xFF4A90E2);

class TambahTokoScreen extends StatefulWidget {
  @override
  _TambahTokoScreenState createState() => _TambahTokoScreenState();
}

class _TambahTokoScreenState extends State<TambahTokoScreen> {
  File? _profileImage;
  File? _qrisImage;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final cloudinary = CloudinaryPublic('dlu5vj2x6', 'si_kasir', cache: false);

  // Controllers untuk field form
  final _namaTokoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String? _profileImageUrl;
  String? _qrisImageUrl;

  @override
  void initState() {
    super.initState();
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

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _namaTokoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
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
                if ((isProfile && _profileImage != null) || (!isProfile && _qrisImage != null))
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
      CloudinaryResponse response = await cloudinary.uploadFile(
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
    if (_formKey.currentState!.validate()) {
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
        // Upload images to Cloudinary if they exist
        if (_profileImage != null) {
          // Upload ke folder profile_images
          _profileImageUrl = await _uploadToCloudinary(_profileImage!, 'profile_images');
          print('Profile image URL: $_profileImageUrl');
        }
        
        if (_qrisImage != null) {
          // Upload ke folder qris_images
          _qrisImageUrl = await _uploadToCloudinary(_qrisImage!, 'qris_images');
          print('QRIS image URL: $_qrisImageUrl');
        }

        // Save data to Firestore
        Map<String, dynamic> tokoData = {
          'nama_toko': _namaTokoController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'profile_image': _profileImageUrl ?? '', // Menyimpan URL lengkap dari Cloudinary
          'qris_image': _qrisImageUrl ?? '', // Menyimpan URL lengkap dari Cloudinary
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Log data yang akan disimpan
        print('Data yang akan disimpan ke Firestore:');
        tokoData.forEach((key, value) {
          print('$key: $value');
        });

        await FirebaseFirestore.instance.collection('toko').add(tokoData);

        // Close loading dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data berhasil disimpan'),
            backgroundColor: primaryBlue,
          ),
        );

        // Navigate back to previous screen after successful save
        Navigator.pop(context);
      } catch (error) {
        // Close loading dialog
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $error'),
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
          'Profil Toko',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                      image: _profileImage != null
                          ? DecorationImage(
                              image: FileImage(_profileImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImage == null
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
                    buildButton('Simpan Profil', primaryBlue,
                        Icons.save_rounded, _submitForm),
                    SizedBox(height: 15),
                    buildButton(
                        'Logout', Colors.red, Icons.logout_rounded, _logout),
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
        child: _qrisImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(
                      _qrisImage!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: primaryBlue),
                        onPressed: () =>
                            _showImagePickerDialog(isProfile: false),
                      ),
                    ),
                  ),
                ],
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