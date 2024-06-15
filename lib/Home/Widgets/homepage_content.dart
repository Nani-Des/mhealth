import 'package:flutter/material.dart';
import 'package:mhealth/Home/Widgets/search_bar.dart';
import 'package:mhealth/Home/Widgets/speech_bubble.dart';
import 'package:mhealth/Home/Widgets/doctors_row_item.dart';

class HomePageContent extends StatelessWidget {
  final VoidCallback onMessagePressed;

  const HomePageContent({
    Key? key,
    required this.onMessagePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBar1(),
            SizedBox(height: 20),
            SpeechBubble(
              onPressed: () {
                print("See Doctor now! tapped");
                // Add your onPressed code here!
              },
              textStyle: TextStyle(
                fontSize: 15.0, // Adjust the font size here
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 20),
            DoctorsRowItem(),
            SizedBox(height: 5),
            Center(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(2.0), // Adjustable padding around the image
                    child: Image.asset(
                      'assets/Images/globe.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      onMessagePressed();
                      // Add your code to display hospitals near the user here
                      print('Show Hospitals near you tapped');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_city_outlined,
                          size: 30,
                          color: Colors.blueAccent,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Show Hospitals near you', // Your text alongside the icon
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
