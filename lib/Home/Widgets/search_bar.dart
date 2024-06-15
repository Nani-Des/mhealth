import 'package:flutter/material.dart';

class SearchBar1 extends StatelessWidget {
  final double borderRadius;

  SearchBar1({this.borderRadius = 10.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.grey),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.blueAccent),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            // Implement location selection logic here
            _showLocationDialog(context);
          },
          child: Container(
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(Icons.location_on, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Location'),
          content: DropdownButton<String>(
            items: <String>[
              'Greater Accra',
              'Volta',
              'Ashanti',
              'Eastern',
              'Western',
              'Northern',
              'Upper East',
              'Upper West',
              'Central',
              'Brong-Ahafo'
            ].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              // Implement location change logic here
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}
