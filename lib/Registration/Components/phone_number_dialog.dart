// phone_number_dialog.dart
import 'package:flutter/material.dart';

class PhoneNumberDialog {
  static Future<void> showPhoneNumberDialog(BuildContext context, Function(String, String, String) onSubmit) async {
    TextEditingController _phoneNumberController = TextEditingController();
    String _selectedRegion = 'Select Region'; // Default value for the dropdown
    String _selectedCountryCode = '+233'; // Default value for the country code dropdown
    PageController _pageController = PageController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must enter a phone number
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter your phone number'),
          content: Container(
            height: 200, // Ensure the container has a fixed height
            width: double.maxFinite, // Ensure the container takes up available width
            child: PageView(
              controller: _pageController,
              physics: BouncingScrollPhysics(),
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _selectedCountryCode,
                          items: <String>['+233', '+86', '+1', '+44', '+91']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            _selectedCountryCode = newValue!;
                            (context as Element).markNeedsBuild(); // Rebuild to update UI
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneNumberController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone, color: Colors.blueAccent),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text('Next'),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      },
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: _selectedRegion,
                      items: <String>['Select Region', 'G.Accra', 'Volta', 'Ashanti', 'Eastern']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        _selectedRegion = newValue!;
                        (context as Element).markNeedsBuild(); // Rebuild to update UI
                      },
                    ),
                    SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text('Submit'),
                      onPressed: () {
                        if (_phoneNumberController.text.isNotEmpty && _selectedRegion != 'Select Region') {
                          onSubmit(_phoneNumberController.text, _selectedCountryCode, _selectedRegion);
                          Navigator.of(context).pop();
                        } else {
                          print('Phone number and region are required');

                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // actions: <Widget>[
          //   TextButton(
          //     child: Text('skip'),
          //     onPressed: () {_pageController.nextPage(
          //       duration: Duration(milliseconds: 300),
          //       curve: Curves.easeIn,
          //     );},
          //   ),
          // ],
        );
      },
    );
  }
}
