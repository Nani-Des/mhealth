import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set background color to transparent
      backgroundColor: Colors.transparent,
      body: Center(
        child: Stack(
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.contain, // Ensure the image fits within the screen
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.pop(context); // Close the full-screen view
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
