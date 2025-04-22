import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shimmer/shimmer.dart';

class AddPostScreen extends State<AddPostScreen> {
  File? _image;
  String? _base64Image;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _IsUploading = false;
  double? _latitude;
  double? _longitude;
  String? _aiCategory;
  String? _aiDescription;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final PickedFile = await _picker.pickImage(source: source);
      if (PickedFile != null) {
        _image = File(PickedFile.path);
        _aiCategory = null;
        _aiDescription = null;
        _descriptionController.clear();
      }
      ;
      await _compressAndEncodeImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _compressAndEncodeImage() async {
    if (_image == null) return;

    try {
      final CompressedImage = await FlutterImageCompress.compressWithFile(
          _image!.path,
          quality: 50);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to compress image: $e')));
      }
    }
  }

}
