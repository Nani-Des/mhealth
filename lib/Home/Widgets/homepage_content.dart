import 'package:flutter/material.dart';
import 'package:mhealth/Home/Widgets/search_bar.dart';
import 'package:mhealth/Home/Widgets/speech_bubble.dart';
import '../../Maps/map_screen.dart';
import 'doctors_row_item.dart';
import 'organization_list_view.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({
    Key? key,
  }) : super(key: key);

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
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


              // Organization ListView (Scrollable)
              Expanded(
                child: OrganizationListView(showSearchBar: false, isReferral: false),
              ),

            ],
          ),
        ),

        // Small Map Image at Bottom Right
        Positioned(
          bottom: 20,
          right: 20,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapScreen()),
              );
            },
            child: Image.asset(
              'assets/Images/globe1.jpg',
              width: 60, // Smaller size
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
