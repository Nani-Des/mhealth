import 'package:flutter/material.dart';
import '../Login/login_screen1.dart';
import 'Widgets/custom_bottom_navbar.dart';
import 'Widgets/search_bar.dart';
import 'Widgets/speech_bubble.dart';



class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Do you have Health needs?',
          style: TextStyle(
            color: Colors.grey, // Change this to your desired color
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: CustomBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add your onPressed code here!
          
          Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => LoginScreen1())) ;    },
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
