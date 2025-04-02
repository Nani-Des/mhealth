import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

class CredentialsContainer extends StatefulWidget {
  final List<TextInputFormatter> inputFormatter;
  bool errorTextField;
  final TextEditingController controller;
  final String title;
  String iconText;
  final String hintText;
  bool isPassword;
  bool isPasswordVisible;
  bool isMobileNumber;
  TextInputType keyboardType;

  CredentialsContainer({
    Key? key,
    required this.title,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.keyboardType = TextInputType.name,
    this.iconText = '@',
    this.errorTextField = false,
    this.isMobileNumber = false,
    required this.hintText,
    required this.controller,
    required this.inputFormatter,
  }) : super(key: key);

  @override
  State<CredentialsContainer> createState() => _CredentialsContainerState();
}

class _CredentialsContainerState extends State<CredentialsContainer> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 2.5),
          child: Text(
            widget.title,
            style: TextStyle(
              color: black,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 12 * screenHeight),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 53 * screenHeight,
              width: 51 * screenWidth,
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: widget.errorTextField
                        ? complementaryRed
                        : appointmentTimeColor,
                    width: 1),
              ),
              child: Center(
                child: widget.isPasswordVisible
                    ? Image.asset(
                        'assets/icons/lock.png',
                        height: 14.22 * screenHeight,
                        width: 12.44 * screenWidth,
                        color: semiGrey,
                      )
                    : Text(
                        widget.iconText,
                        style: TextStyle(
                          color: semiGrey,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12 * screenWidth),
            Container(
              height: 53 * screenHeight,
              width: 288 * screenWidth,
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: widget.errorTextField
                        ? complementaryRed
                        : appointmentTimeColor,
                    width: 1),
              ),
              padding: EdgeInsets.only(left: 16 * screenWidth),
              child: TextField(
                inputFormatters: widget.inputFormatter,
                maxLength: widget.isMobileNumber ? 10 : null,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: widget.keyboardType,
                controller: widget.controller,
                obscureText: widget.isPassword ? true : false,
                textCapitalization: TextCapitalization.sentences,
                cursorHeight: 18 * screenHeight,
                autofocus: false,
                autocorrect: true,
                enableSuggestions: true,
                clipBehavior: Clip.antiAlias,
                cursorColor: black.withOpacity(0.6),
                decoration: InputDecoration(
                    counterText: '',
                    suffixIcon: widget.isPasswordVisible
                        ? Padding(
                            padding: EdgeInsets.only(right: screenWidth * 4.0),
                            child: IconButton(
                                highlightColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                onPressed: () {
                                  setState(() {
                                    widget.isPassword = !widget.isPassword;
                                    if (widget.isPassword == true) {
                                      widget.isPassword = true;
                                    } else {
                                      widget.isPassword = false;
                                    }
                                  });
                                },
                                icon: widget.isPassword
                                    ? Icon(
                                        Icons.visibility,
                                        color: semiGrey,
                                      )
                                    : Icon(
                                        Icons.visibility_off_rounded,
                                        color: semiGrey,
                                      )),
                          )
                        : null,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.w200,
                      color: black,
                      fontSize: 12,
                    )),
                style: TextStyle(
                  overflow: TextOverflow.clip,
                  color: black,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
