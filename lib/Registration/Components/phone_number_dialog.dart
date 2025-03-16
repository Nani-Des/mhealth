// phone_number_dialog.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class PhoneNumberDialog {
  static Future<void> showPhoneNumberDialog(
      BuildContext context, Function(String, String, String, String?) onSubmit) async {
    TextEditingController _phoneNumberController = TextEditingController();
    String _selectedRegion = 'Select Region';
    String _selectedCountryCode = '+233';
    PageController _pageController = PageController();
    File? _selectedImage; // To store the picked image
    final ImagePicker _picker = ImagePicker();

    // Function to pick image from gallery
    Future<void> _pickImage() async {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _selectedImage = File(image.path);
        (context as Element).markNeedsBuild(); // Rebuild to show selected image
      }
    }

    // Function to upload image to Firebase Storage
    Future<String?> _uploadImage(String userId) async {
      if (_selectedImage == null) return null;

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child(userId)
            .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(_selectedImage!);
        return await storageRef.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        return null;
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter your phone number'),
          content: Container(
            height: 300, // Increased height to accommodate image picker
            width: double.maxFinite,
            child: PageView(
              controller: _pageController,
              physics: BouncingScrollPhysics(),
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _selectedCountryCode,
                          items: <String>['+233', '+86', '+1', '+44', '+91']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            _selectedCountryCode = newValue!;
                            (context as Element).markNeedsBuild();
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneNumberController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone, color: Colors.blueAccent),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text('Next'),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      },
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: _selectedRegion,
                      items: <String>['Select Region', 'G.Accra', 'Volta', 'Ashanti', 'Eastern']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        _selectedRegion = newValue!;
                        (context as Element).markNeedsBuild();
                      },
                    ),
                    SizedBox(height: 10),
                    // Image upload section
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text('Upload Profile Picture (Optional)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                    SizedBox(height: 10),
                    if (_selectedImage != null)
                      Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text('Submit'),
                      onPressed: () async {
                        if (_phoneNumberController.text.isNotEmpty &&
                            _selectedRegion != 'Select Region') {
                          String? imageUrl;
                          String userId = '${_selectedCountryCode}${_phoneNumberController.text}';
                          if (_selectedImage != null) {
                            imageUrl = await _uploadImage(userId);
                          }
                          onSubmit(
                            _phoneNumberController.text,
                            _selectedCountryCode,
                            _selectedRegion,
                            imageUrl,
                          );
                          Navigator.of(context).pop();
                        } else {
                          print('Phone number and region are required');
                        }
                      },
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
}