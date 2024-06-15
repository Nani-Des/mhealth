import 'package:flutter/services.dart';

class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-@]*$');
    if (emailRegex.hasMatch(newValue.text)) {
      return newValue;
    } else {
      return oldValue;
    }
  }
}