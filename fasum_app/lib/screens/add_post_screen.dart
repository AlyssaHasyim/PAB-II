import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({Key? key}) : super(key: key);

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  File? _image;
  String? _base64Image;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double? _latitude;
  double? _longitude;
  String? _aiCategory;
  String? _aiDescription;
  bool _isGenerating = false;

  // Categories for the post
  List<String> categories = [
    'Jalan Rusak',
    'Marka Pudar',
    'Lampu Mati',
    'Trotoar Rusak',
    'Rambu Rusak',
    'Jembatan Rusak',
    'Sampah Menumpuk',
    'Saluran Tersumbat',
    'Sungai Tercemar',
    'Sampah Sungai',
    'Pohon Tumbang',
    'Taman Rusak',
    'Fasilitas Rusak',
    'Pipa Bocor',
    'Vandalisme',
    'Banjir',
    'Lainnya'
  ];

  // Store selected categories
  Set<String> _selectedCategories = {};
  String? _selectedCategory;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Show category selection modal
  void _showCategorySelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: categories.map((category) {
            return ListTile(
              title: Text(category),
              onTap: () {
                setState(() {
                  _aiCategory = category;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _aiCategory = null;
          _aiDescription = null;
          _descriptionController.clear();
        });
        await _compressAndEncodeImage();
        await _generateDescriptionWithAI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  // Compress and encode image to Base64
  Future<void> _compressAndEncodeImage() async {
    if (_image == null) return;
    try {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _image!.path,
        quality: 50,
      );
      if (compressedImage != null) {
        setState(() {
          _base64Image = base64Encode(compressedImage);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to compress image: $e')));
      }
    }
  }

  // Generate AI description based on image
Future<void> _generateDescriptionWithAI() async {
  if (_image == null) return;
  setState(() => _isGenerating = true);
  
  try {
    final imageBytes = await _image!.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // Replace [YOUR_API_KEY] with the actual API key
    const apiKey = '[AIzaSyDQSr4xb37DV3ttHEPt43Zd4lTVI8mPQWI]'; // Ensure this is securely stored
    const url = 'https://generativelanguage.googleapis.com/v1/models/gemini2.0-flash:generateContent?key=$apiKey';

    // Construct the request body
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "inlineData": {
                "mimeType": "image/jpeg",
                "data": base64Image,
              }
            },
            {
              'Berdasarkan foto ini, identifikasi satu kategori utama kerusakan fasilitas umum dari daftar berikut: '
              'Jalan Rusak, Marka Pudar, Lampu Mati, Trotoar Rusak, Rambu Rusak, Jembatan Rusak, Sampah Menumpuk, '
              'Saluran Tersumbat, Sungai Tercemar, Sampah Sungai, Pohon Tumbang, Taman Rusak, Fasilitas Rusak, Pipa Bocor, '
              'Vandalisme, Banjir, dan Lainnya. Pilih kategori yang paling dominan atau paling mendesak untuk dilaporkan. '
              'Buat deskripsi singkat untuk laporan perbaikan, dan tambahkan permohonan perbaikan. Fokus pada kerusakan yang terlihat '
              'dan hindari spekulasi.\n\nFormat output yang diinginkan:\nKategori: [satu kategori yang dipilih]\nDeskripsi: [deskripsi singkat]',
            }
          ]
        }
      ]
    });

    // Set the request headers
    final headers = {
      'Content-Type': 'application/json',
    };

    // Send the request to the API
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // Parse the AI response text
      final text = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
      print("AI TEXT: $text");

      if (text != null && text.isNotEmpty) {
        final lines = text.trim().split('\n');
        String? category;
        String? description;

        // Extract category and description from the AI response
        for (var line in lines) {
          final lower = line.toLowerCase();
          if (lower.startsWith('kategori:')) {
            category = line.substring(9).trim();
          } else if (lower.startsWith('deskripsi:') || lower.startsWith('keterangan:')) {
            description = line.substring(line.indexOf(':') + 1).trim();
          }
        }

        description ??= text.trim(); // Fallback to the whole response if no description found

        setState(() {
          _aiCategory = category ?? 'Tidak diketahui'; // Default category if none found
          _aiDescription = description!;
          _descriptionController.text = _aiDescription!; // Update the description field
        });
      }
    } else {
      debugPrint('Request failed: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get AI response. Please try again.')),
      );
    }
  } catch (e) {
    debugPrint('Failed to generate AI description: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred while generating the description.')),
    );
  } finally {
    if (mounted) setState(() => _isGenerating = false); // Ensure widget is still mounted
  }
}


  // Retrieve user location
  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 10));

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Failed to retrieve location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retrieve location: $e')));
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
  }

  // Submit the post to Firebase
  Future<void> _submitPost() async {
    if (_base64Image == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image and description.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please sign in.')),
      );
      return;
    }

    try {
      await _getLocation();
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final fullName = userDoc.data()?['fullName'] ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('posts').add({
        'image': _base64Image,
        'description': _descriptionController.text,
        'category': _aiCategory ?? 'Tidak diketahui',
        'createdAt': now,
        'latitude': _latitude,
        'longitude': _longitude,
        'fullName': fullName,
        'userId': uid,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post uploaded successfully!')),
      );
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload the post: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Show image source dialog (camera/gallery)
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Shimmer effect while generating description
            if (_isGenerating)
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                    ),
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            // Category selection
            if (_aiCategory != null && !_isGenerating)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _showCategorySelection,
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_aiCategory!),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit, size: 16),
                          ],
                        ),
                        backgroundColor: Colors.blue[100],
                      ),
                    ),
                    if (_image != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Generate another description',
                        onPressed: _generateDescriptionWithAI,
                      ),
                  ],
                ),
              ),
            // Description input
            Offstage(
              offstage: _isGenerating,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Add a brief description...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.green,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
