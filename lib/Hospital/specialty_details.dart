import 'package:flutter/material.dart';

class SpecialtyDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Specialty Details'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Row(
        children: [
          // Labels section (30%)
          Container(
            width: MediaQuery.of(context).size.width * 0.30,
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: [
                // Adding larger spacing between each label
                _specialtyLabel('Cardiology'),
                SizedBox(height: 15),
                _specialtyLabel('Dentistry'),
                SizedBox(height: 15),
                _specialtyLabel('Surgery'),
                SizedBox(height: 15),
                _specialtyLabel('Pediatrics'),
                SizedBox(height: 15),
                _specialtyLabel('Neurology'),
                SizedBox(height: 15),
                _specialtyLabel('Nephrology'),
                SizedBox(height: 15),
                _specialtyLabel('Hepatology'),
              ],
            ),
          ),
          // Doctor details section (40%)
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _doctorDetailCard('Dr. Nani', 'Experience: 3 yrs'),
                SizedBox(height: 10),
                _doctorDetailCard('Dr. Mike', 'Experience: 20 yrs'),
                SizedBox(height: 10),
                _doctorDetailCard('Dr. Nat', 'Experience: 12 yrs'),
              ],
            ),
          ),
          // Avatar section removed as we're now integrating avatars in the doctor cards
        ],
      ),
    );
  }

  // Function to create a label for specialties with improved appearance
  Widget _specialtyLabel(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  // Function to create a doctor detail card with avatar
  Widget _doctorDetailCard(String name, String experience) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 10), // Added margin for better spacing
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Increased padding for better appearance
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70, // Increased width
              height: 70, // Increased height
              decoration: BoxDecoration(
                shape: BoxShape.rectangle, // Changed to rectangle
                border: Border.all(color: Colors.grey, width: 1), // Added border
                borderRadius: BorderRadius.circular(10), // Rounded corners
                color: Colors.grey[200], // Background color
              ),
              child: Center(
                child: Icon(
                  Icons.person, // Human icon
                  size: 50,
                  color: Colors.grey[700],
                ),
              ),
            ),
            SizedBox(width: 15), // Space between avatar and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5), // Added space between name and experience
                  Text(
                    experience,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
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
