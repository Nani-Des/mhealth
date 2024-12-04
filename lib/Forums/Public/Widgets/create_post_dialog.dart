import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../Services/forum_firebase_service.dart';

class CreatePostDialog extends StatefulWidget {
  final String userId;

  const CreatePostDialog({required this.userId});

  @override
  _CreatePostDialogState createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final TextEditingController _contentController = TextEditingController();
  String? _imageUrl;

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('post_images/$fileName');
      UploadTask uploadTask = ref.putFile(File(pickedFile.path));
      TaskSnapshot snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isNotEmpty) {
      await ForumFirebaseService().createPost(
        widget.userId,
        _contentController.text,
        _imageUrl,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _contentController,
            decoration: InputDecoration(hintText: 'What\'s happening?'),
          ),
          SizedBox(height: 10),
          TextButton.icon(
            onPressed: _uploadImage,
            icon: Icon(Icons.image),
            label: Text('Upload Image'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        TextButton(onPressed: _submitPost, child: Text('Post')),
      ],
    );
  }
}
