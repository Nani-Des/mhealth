import 'package:flutter/material.dart';

import '../constants.dart';

class CredentialsButton extends StatelessWidget {
  final VoidCallback screen;
  String buttonText;
  bool isConfirmLater;
  CredentialsButton({
    Key? key,
    this.buttonText = 'Login',
    required this.screen,
    this.isConfirmLater = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: screen,
      child: Container(
        height: 53 * screenHeight,
        width: 351 * screenWidth,
        decoration: BoxDecoration(
          color: isConfirmLater ? white : primary,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Text(
            buttonText,
            style: TextStyle(
              color: isConfirmLater ? semiGrey : white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
