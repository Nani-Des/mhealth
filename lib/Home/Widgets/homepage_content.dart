import 'package:flutter/material.dart';
import 'package:mhealth/Home/Widgets/search_bar.dart';
import 'package:mhealth/Home/Widgets/speech_bubble.dart';
import '../../Maps/map_screen.dart';
import 'doctors_row_item.dart';
import 'organization_list_view.dart'; // Import the new OrganizationListView

class HomePageContent extends StatefulWidget {
  final VoidCallback onMessagePressed;

  const HomePageContent({
    Key? key,
    required this.onMessagePressed,
  }) : super(key: key);

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  bool _showListView = false; // Flag to toggle between globe and list view

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchBar1(),
          SizedBox(height: 6),
          SpeechBubble(
            onPressed: () {
              print("See Doctor now! tapped");
            },
            textStyle: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          DoctorsRowItem(),
          SizedBox(height: 8),

          // Add Expanded to prevent overflow
          Expanded(
            child: SingleChildScrollView(
              child: _showListView
                  ? Column(
                children: [
                  Container(
                    height: 380, // Set a fixed height for the list
                    child: OrganizationListView(),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapScreen()),
                      );
                    },
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                ],
              )
                  : _buildGlobeAndText(context),
            ),
          ),
        ],
      ),
    );
  }


  // Function to build the globe image and "Show hospitals near you" text
  Widget _buildGlobeAndText(BuildContext context) {
    return Center(
      child: Column(
        children: [
          // Wrap the Image.asset with GestureDetector to handle onTap
          GestureDetector(
            onTap: () {
              // Navigate to the MapScreen when the globe image is tapped
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapScreen()),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(2.0), // Adjustable padding around the image
              child: Image.asset(
                'assets/Images/globe1.jpg',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              setState(() {
                _showListView = true; // Show list view when tapped
              });
              widget.onMessagePressed();
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
                  'Show Hospitals near you',
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
    );
  }

}
