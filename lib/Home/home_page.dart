import 'package:flutter/material.dart';
import 'package:mhealth/Hospital/specialty_details.dart';
import '../Login/login_screen1.dart';
import 'Widgets/custom_bottom_navbar.dart';
import 'Widgets/homepage_content.dart';

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
      body: HomePageContent(
        onMessagePressed: () {
          print('Message icon tapped');
          // Add your onPressed code here!
        },
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: CustomBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add your onPressed code here!
          Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen1()));
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
