import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Hospital').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final hospitals = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(), // Prevents inner scrolling
          itemCount: hospitals.length,
          itemBuilder: (context, index) {
            final hospitalData = hospitals[index].data() as Map<String, dynamic>;
            final backgroundImage = hospitalData['Background Image'] ?? '';
            final city = hospitalData['City'] ?? 'Unknown City';
            final contact = hospitalData['Contact'] ?? 'No Contact Info';

            return GestureDetector(
              onTap: () {
                // Add your onPress logic here, for example, navigating to a detail page
                print('Card tapped for: $city');
                // You can also use Navigator.push to route to a detailed page
              },
              child: HospitalCard(
                backgroundImage: backgroundImage,
                city: city,
                contact: contact,
              ),
            );
          },
        );
      },
    );
  }
}

class HospitalCard extends StatelessWidget {
  final String backgroundImage;
  final String city;
  final String contact;

  const HospitalCard({
    Key? key,
    required this.backgroundImage,
    required this.city,
    required this.contact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 5.0), // Space between cards
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0), // Rounded corners
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
            child: Image.network(
              backgroundImage,
              height: 100, // Height for the background image
              width: double.infinity,
              fit: BoxFit.cover, // Ensures image covers entire card width
              errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 100),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center, // City name at the center
                  child: Text(
                    city,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight, // Contact at the bottom right
                  child: Text(
                    contact,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
