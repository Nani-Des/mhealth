import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatefulWidget {
  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.local_hospital),
                label: 'Hospitals',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.medical_services), // Use this icon instead of Icons.first_aid
                label: 'First Aid',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold), // Adjust selected font size here
            unselectedLabelStyle: TextStyle(fontSize: 8.0), // Adjust unselected font size here
            backgroundColor: Colors.transparent, // Make background transparent so Container color is visible
            elevation: 0, // Remove shadow from BottomNavigationBar
          ),
        ),
      ),
    );
  }
}
